#!/usr/bin/env python3
"""
RISC-V CPU Automated Verification Script
Converts test cases, generates golden reference, and verifies simulation results
"""

import sys
import os
import subprocess
from pathlib import Path

# ANSI color codes for terminal output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

def find_vivado():
    """Search for the Vivado executable. Returns full path or None."""
    import shutil
    import glob

    vivado_in_path = shutil.which('vivado')
    if vivado_in_path:
        return vivado_in_path

    # Unified installer layout (2022+): C:/Xilinx/<version>/Vivado/bin/vivado.bat
    # Standalone layout (pre-2022):     C:/Xilinx/Vivado/<version>/bin/vivado.bat
    for pattern in ['C:/Xilinx/*/Vivado/bin/vivado.bat',
                    'C:/Xilinx/Vivado/*/bin/vivado.bat']:
        matches = sorted(glob.glob(pattern), reverse=True)  # newest version first
        if matches:
            return matches[0]

    return None


def run_simulation(script_path, vivado_path):
    """
    Invoke Vivado in batch mode to run RTL simulation.
    Returns True if simulation completed and output files exist, False otherwise.
    """
    RF_OUT = os.path.join('Testbench', 'RF.out')
    DM_OUT = os.path.join('Testbench', 'DM.out')

    # Kill any stale xsim processes that may have simulate.log locked
    for proc in ['xsim.exe', 'xsimk.exe']:
        subprocess.run(['taskkill', '/F', '/IM', proc], capture_output=True)

    print(f"{Colors.CYAN}[Step 4/4] Launching Vivado batch simulation...{Colors.RESET}")
    print(f"  Vivado : {vivado_path}")
    print(f"  Script : {script_path}")
    print(f"  {Colors.YELLOW}This may take 2-5 minutes. Please wait...{Colors.RESET}\n")

    cmd = [vivado_path, '-mode', 'batch', '-source', script_path, '-nolog', '-nojournal']

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='ignore',
            timeout=600,  # 10-minute hard ceiling
        )
    except subprocess.TimeoutExpired:
        print(f"{Colors.RED}Error: Vivado simulation timed out after 10 minutes.{Colors.RESET}")
        print(f"{Colors.YELLOW}Tip: Check that Script.tcl ends with close_sim and close_project.{Colors.RESET}")
        return False
    except FileNotFoundError:
        print(f"{Colors.RED}Error: Could not launch Vivado at:{Colors.RESET}")
        print(f"  {vivado_path}")
        return False
    except Exception as e:
        print(f"{Colors.RED}Error launching Vivado: {e}{Colors.RESET}")
        return False

    combined_output = result.stdout + result.stderr

    # Check for ERROR lines in Vivado output
    error_lines = [
        line for line in combined_output.splitlines()
        if line.strip().startswith('ERROR:')
    ]
    if error_lines:
        print(f"{Colors.RED}Vivado reported {len(error_lines)} error(s):{Colors.RESET}")
        for line in error_lines:
            print(f"  {line}")
        return False

    if result.returncode != 0:
        print(f"{Colors.RED}Vivado exited with code {result.returncode}.{Colors.RESET}")
        print(f"{Colors.YELLOW}Vivado output (last 20 lines):{Colors.RESET}")
        for line in combined_output.splitlines()[-20:]:
            print(f"  {line}")
        return False

    # Verify output files exist and are non-empty
    missing = []
    for path in [RF_OUT, DM_OUT]:
        if not os.path.exists(path):
            missing.append(path)
        elif os.path.getsize(path) == 0:
            missing.append(f"{path} (exists but is empty)")

    if missing:
        print(f"{Colors.RED}Simulation completed but output files are missing or empty:{Colors.RESET}")
        for m in missing:
            print(f"  - {m}")
        print(f"{Colors.YELLOW}Tip: Check that close_sim appears in Script.tcl before close_project.{Colors.RESET}")
        return False

    print(f"{Colors.GREEN}✓ Simulation complete. RF.out and DM.out generated.{Colors.RESET}")
    return True


def print_header(title):
    """Print a formatted header"""
    print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{title.center(60)}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")

def check_testcase_exists(testcase_num):
    """Check if the test case file exists"""
    testcase_file = f"Pattern/TestCase{testcase_num}.dat"
    return os.path.exists(testcase_file)

def convert_testcase(testcase_num):
    """Convert test case to IM.dat and IM.coe using Instr_Transfer.py and dat2coe.py"""
    print(f"{Colors.CYAN}[Step 1/4] Converting TestCase{testcase_num}.dat to IM.dat...{Colors.RESET}")

    testcase_file = f"Pattern/TestCase{testcase_num}.dat"

    if not os.path.exists(testcase_file):
        print(f"{Colors.RED}Error: {testcase_file} not found!{Colors.RESET}")
        return False

    try:
        # Run Instr_Transfer.py
        result = subprocess.run(
            ['python', 'Pattern/Instr_Transfer.py', testcase_file],
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='ignore'  # 忽略編碼錯誤
        )

        if result.returncode != 0:
            print(f"{Colors.RED}Error during conversion:{Colors.RESET}")
            print(result.stderr)
            return False

        # Move IM.dat to Testbench directory
        if os.path.exists('IM.dat'):
            import shutil
            shutil.move('IM.dat', 'Testbench/IM.dat')
            print(f"{Colors.GREEN}✓ Successfully converted and moved to Testbench/IM.dat{Colors.RESET}")
        else:
            print(f"{Colors.RED}Error: IM.dat was not generated{Colors.RESET}")
            return False

        # Convert IM.dat to IM.coe for Vivado BRAM initialization
        print(f"\n{Colors.CYAN}[Step 2/4] Converting IM.dat to IM.coe...{Colors.RESET}")
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("dat2coe", "Testbench/dat2coe.py")
            dat2coe = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(dat2coe)
            dat2coe.dat_to_coe('Testbench/IM.dat', 'Testbench/IM.coe')
            print(f"{Colors.GREEN}✓ Successfully converted to Testbench/IM.coe{Colors.RESET}")
        except Exception as e:
            print(f"{Colors.RED}Error converting to .coe: {e}{Colors.RESET}")
            return False

        return True

    except Exception as e:
        print(f"{Colors.RED}Error running Instr_Transfer.py: {e}{Colors.RESET}")
        return False

def generate_golden():
    """Generate golden reference using Golden_Result.py"""
    print(f"\n{Colors.CYAN}[Step 3/4] Generating golden reference...{Colors.RESET}")

    if not os.path.exists('Testbench/Golden_Result.py'):
        print(f"{Colors.RED}Error: Testbench/Golden_Result.py not found!{Colors.RESET}")
        return False

    try:
        # Change to Testbench directory and run Golden_Result.py
        result = subprocess.run(
            ['python', 'Golden_Result.py'],
            cwd='Testbench',
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='ignore'  # 忽略編碼錯誤
        )

        if result.returncode != 0:
            print(f"{Colors.RED}Error generating golden reference:{Colors.RESET}")
            print(result.stderr)
            return False

        # Check if golden files were created
        if os.path.exists('Testbench/RF.golden') and os.path.exists('Testbench/DM.golden'):
            print(f"{Colors.GREEN}✓ Successfully generated RF.golden and DM.golden{Colors.RESET}")
            return True
        else:
            print(f"{Colors.RED}Error: Golden files were not generated{Colors.RESET}")
            return False

    except Exception as e:
        print(f"{Colors.RED}Error running Golden_Result.py: {e}{Colors.RESET}")
        return False

def parse_file(filename):
    """
    Parse output file with format: [Index] hexvalue
    Returns dictionary: {index: value}
    """
    data = {}
    if not os.path.exists(filename):
        return None

    with open(filename, 'r', encoding='latin-1') as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith('//'):
                continue

            # Parse format: [Index] hexvalue
            if line.startswith('['):
                try:
                    # Extract index and value
                    parts = line.split(']')
                    index = int(parts[0][1:])  # Remove '[' and convert to int
                    value = parts[1].strip()   # Get hex value
                    data[index] = value.lower()  # Normalize to lowercase
                except (IndexError, ValueError) as e:
                    print(f"{Colors.YELLOW}Warning: Could not parse line '{line}' in {filename}{Colors.RESET}")
                    continue

    return data

def compare_data(sim_data, golden_data, name):
    """
    Compare simulation output with golden reference
    Returns (pass, mismatch_count, details)
    """
    if sim_data is None:
        return False, 0, f"{name} simulation output not found"

    if golden_data is None:
        return False, 0, f"{name} golden reference not found"

    # Get all indices from both datasets
    all_indices = set(sim_data.keys()) | set(golden_data.keys())

    mismatches = []
    for idx in sorted(all_indices):
        sim_val = sim_data.get(idx, 'MISSING')
        golden_val = golden_data.get(idx, 'MISSING')

        if sim_val != golden_val:
            mismatches.append({
                'index': idx,
                'simulation': sim_val,
                'golden': golden_val
            })

    if mismatches:
        details = f"\n  {Colors.RED}Found {len(mismatches)} mismatch(es):{Colors.RESET}\n"
        for mismatch in mismatches:
            details += f"    [{mismatch['index']}] "
            details += f"Simulation: {mismatch['simulation']:<12} "
            details += f"Golden: {mismatch['golden']:<12}\n"
        return False, len(mismatches), details

    return True, 0, ""

def verify():
    """
    Verification function
    """
    print_header("Verification Results")

    # Change to Testbench directory
    os.chdir('Testbench')

    # Check for required files
    files_to_check = ['RF.out', 'RF.golden', 'DM.out', 'DM.golden']
    missing_files = []

    for filename in files_to_check:
        if not os.path.exists(filename):
            missing_files.append(filename)

    if missing_files:
        print(f"{Colors.RED}Error: Missing required files:{Colors.RESET}")
        for filename in missing_files:
            print(f"  - {filename}")
        print(f"\n{Colors.YELLOW}Please run the RTL simulation first to generate RF.out and DM.out.{Colors.RESET}")
        os.chdir('..')
        return {'success': False, 'rf_pass': False, 'dm_pass': False,
                'rf_mismatches': 0, 'dm_mismatches': 0, 'rf_details': '', 'dm_details': ''}

    # Parse Register File outputs
    print(f"{Colors.BLUE}[1/4] Loading Register File simulation output...{Colors.RESET}")
    rf_sim = parse_file('RF.out')
    print(f"      Loaded {len(rf_sim) if rf_sim else 0} register values")

    print(f"{Colors.BLUE}[2/4] Loading Register File golden reference...{Colors.RESET}")
    rf_golden = parse_file('RF.golden')
    print(f"      Loaded {len(rf_golden) if rf_golden else 0} register values")

    # Parse Data Memory outputs
    print(f"{Colors.BLUE}[3/4] Loading Data Memory simulation output...{Colors.RESET}")
    dm_sim = parse_file('DM.out')
    print(f"      Loaded {len(dm_sim) if dm_sim else 0} memory values")

    print(f"{Colors.BLUE}[4/4] Loading Data Memory golden reference...{Colors.RESET}")
    dm_golden = parse_file('DM.golden')
    print(f"      Loaded {len(dm_golden) if dm_golden else 0} memory values")

    print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{'Comparison Results'.center(60)}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")

    # Compare Register File
    print(f"{Colors.BOLD}Register File (RF) Verification:{Colors.RESET}")
    rf_pass, rf_mismatches, rf_details = compare_data(rf_sim, rf_golden, "RF")

    if rf_pass:
        print(f"  {Colors.GREEN}✓ PASSED{Colors.RESET} - All {len(rf_sim)} registers match")
    else:
        print(f"  {Colors.RED}✗ FAILED{Colors.RESET}{rf_details}")

    # Compare Data Memory
    print(f"\n{Colors.BOLD}Data Memory (DM) Verification:{Colors.RESET}")
    dm_pass, dm_mismatches, dm_details = compare_data(dm_sim, dm_golden, "DM")

    if dm_pass:
        print(f"  {Colors.GREEN}✓ PASSED{Colors.RESET} - All {len(dm_sim)} memory locations match")
    else:
        print(f"  {Colors.RED}✗ FAILED{Colors.RESET}{dm_details}")

    # Final summary
    print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
    print(f"{Colors.BOLD}{'Summary'.center(60)}{Colors.RESET}")
    print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")

    total_tests = 2
    passed_tests = sum([rf_pass, dm_pass])
    overall = (passed_tests == total_tests)

    os.chdir('..')

    if overall:
        print(f"  {Colors.GREEN}{Colors.BOLD}ALL TESTS PASSED!{Colors.RESET}")
        print(f"  {Colors.GREEN}Your CPU simulation matches the golden reference perfectly.{Colors.RESET}\n")
    else:
        print(f"  {Colors.RED}Tests Passed: {passed_tests}/{total_tests}{Colors.RESET}")
        print(f"  {Colors.RED}Tests Failed: {total_tests - passed_tests}/{total_tests}{Colors.RESET}")
        total_mismatches = rf_mismatches + dm_mismatches
        print(f"  {Colors.RED}Total Mismatches: {total_mismatches}{Colors.RESET}\n")

    return {
        'success': overall,
        'rf_pass': rf_pass,
        'dm_pass': dm_pass,
        'rf_mismatches': rf_mismatches,
        'dm_mismatches': dm_mismatches,
        'rf_details': rf_details,
        'dm_details': dm_details,
    }

def run_all_testcases():
    """
    Run all 12 test cases end-to-end and print a final summary.
    Returns True if every test case passed.
    """
    print_header("RISC-V CPU - Running All Test Cases (1-12)")

    vivado_path = find_vivado()
    if vivado_path is None:
        print(f"{Colors.RED}Error: Vivado executable not found. Cannot run simulation.{Colors.RESET}")
        sys.exit(1)

    script_tcl = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Script.tcl')
    if not os.path.exists(script_tcl):
        print(f"{Colors.RED}Error: Script.tcl not found at {script_tcl}{Colors.RESET}")
        sys.exit(1)

    results = {}      # testcase_num -> result dict from verify()
    sim_failures = [] # test cases where simulation itself failed
    skipped = []      # test cases where .dat file not found

    for i in range(1, 13):
        print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
        print(f"{Colors.BOLD}  [ TestCase {i} / 12 ]{Colors.RESET}")
        print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")

        if not check_testcase_exists(i):
            print(f"{Colors.YELLOW}Skipped: Pattern/TestCase{i}.dat not found.{Colors.RESET}")
            skipped.append(i)
            continue

        if not convert_testcase(i):
            print(f"{Colors.RED}Skipped: TestCase{i} conversion failed.{Colors.RESET}")
            skipped.append(i)
            continue

        if not generate_golden():
            print(f"{Colors.RED}Skipped: TestCase{i} golden generation failed.{Colors.RESET}")
            skipped.append(i)
            continue

        if not run_simulation(script_tcl, vivado_path):
            print(f"{Colors.RED}Skipped: TestCase{i} simulation failed.{Colors.RESET}")
            sim_failures.append(i)
            continue

        result = verify()
        results[i] = result

    # ==================== Final Summary ====================
    print_header("Final Summary - All Test Cases")

    # Table header
    print(f"  {'TestCase':<12}  {'RF':<14}  {'DM':<14}  Result")
    print(f"  {'-'*12}  {'-'*14}  {'-'*14}  {'-'*10}")

    passed_count = 0
    for i in range(1, 13):
        if i in skipped:
            print(f"  TestCase{i:<3}   {'N/A':<14}  {'N/A':<14}  {Colors.YELLOW}— SKIPPED{Colors.RESET}")
            continue
        if i in sim_failures:
            print(f"  TestCase{i:<3}   {'N/A':<14}  {'N/A':<14}  {Colors.RED}✗ SIM FAIL{Colors.RESET}")
            continue
        if i not in results:
            continue

        r = results[i]
        rf_label = "PASS" if r['rf_pass'] else f"FAIL({r['rf_mismatches']})"
        dm_label = "PASS" if r['dm_pass'] else f"FAIL({r['dm_mismatches']})"
        res_label = "✓ PASS" if r['success'] else "✗ FAIL"
        rf_c  = Colors.GREEN if r['rf_pass'] else Colors.RED
        dm_c  = Colors.GREEN if r['dm_pass'] else Colors.RED
        res_c = Colors.GREEN if r['success'] else Colors.RED
        print(f"  TestCase{i:<3}   {rf_c}{rf_label:<14}{Colors.RESET}  {dm_c}{dm_label:<14}{Colors.RESET}  {res_c}{res_label}{Colors.RESET}")
        if r['success']:
            passed_count += 1

    # Failure details
    failed_cases = [i for i in sorted(results.keys()) if not results[i]['success']]
    if failed_cases:
        print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}")
        print(f"{Colors.BOLD}{'Failure Details'.center(60)}{Colors.RESET}")
        print(f"{Colors.BOLD}{'='*60}{Colors.RESET}\n")
        for i in failed_cases:
            r = results[i]
            print(f"{Colors.BOLD}TestCase{i}:{Colors.RESET}")
            if not r['rf_pass'] and r['rf_details']:
                print(f"  Register File:{r['rf_details']}")
            if not r['dm_pass'] and r['dm_details']:
                print(f"  Data Memory:{r['dm_details']}")

    # Overall result
    total_run = len(results)
    print(f"\n{Colors.BOLD}{'='*60}{Colors.RESET}\n")
    if total_run == 0:
        print(f"  {Colors.RED}No test cases were completed.{Colors.RESET}\n")
        return False

    if passed_count == total_run and not sim_failures:
        print(f"  {Colors.GREEN}{Colors.BOLD}ALL {total_run} TEST CASES PASSED!{Colors.RESET}\n")
    else:
        print(f"  Passed : {Colors.GREEN}{passed_count}/{total_run}{Colors.RESET}")
        if sim_failures:
            print(f"  Sim failures : {Colors.RED}{len(sim_failures)}{Colors.RESET}  (TestCase {', '.join(str(x) for x in sim_failures)})")
        if failed_cases:
            print(f"  Failed : {Colors.RED}{len(failed_cases)}/{total_run}{Colors.RESET}  (TestCase {', '.join(str(x) for x in failed_cases)})")
        print()

    return passed_count == total_run and not sim_failures


def main():
    """
    Main entry point
    """
    try:
        print_header("RISC-V CPU Automated Verification")

        # ==================== Stage 1: Test Case Conversion ====================
        print(f"{Colors.BOLD}Stage 1: Test Case Conversion & Golden Generation{Colors.RESET}\n")

        # List available test cases
        print(f"{Colors.CYAN}Available Test Cases:{Colors.RESET}")
        for i in range(1, 13):
            if check_testcase_exists(i):
                print(f"  [{i}] TestCase{i}.dat ✓")
            else:
                print(f"  [{i}] TestCase{i}.dat {Colors.RED}(not found){Colors.RESET}")

        # Get user input
        while True:
            try:
                testcase_input = input(f"\n{Colors.BOLD}Enter test case [1-12] or 'all' to run all: {Colors.RESET}").strip().lower()

                if testcase_input == 'all':
                    success = run_all_testcases()
                    sys.exit(0 if success else 1)

                testcase_num = int(testcase_input)

                if 1 <= testcase_num <= 12:
                    if check_testcase_exists(testcase_num):
                        break
                    else:
                        print(f"{Colors.RED}TestCase{testcase_num}.dat not found. Please choose another.{Colors.RESET}")
                else:
                    print(f"{Colors.RED}Please enter a number between 1 and 12.{Colors.RESET}")
            except ValueError:
                print(f"{Colors.RED}Invalid input. Please enter a number or 'all'.{Colors.RESET}")
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}Operation cancelled by user.{Colors.RESET}")
                return

        # Convert test case
        print()
        if not convert_testcase(testcase_num):
            print(f"\n{Colors.RED}Failed to convert test case. Exiting.{Colors.RESET}")
            sys.exit(1)

        # Generate golden reference
        if not generate_golden():
            print(f"\n{Colors.RED}Failed to generate golden reference. Exiting.{Colors.RESET}")
            sys.exit(1)

        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ Stage 1 completed successfully!{Colors.RESET}")
        print(f"{Colors.GREEN}  - IM.dat generated in Testbench/{Colors.RESET}")
        print(f"{Colors.GREEN}  - IM.coe generated in Testbench/ (for Vivado BRAM initialization){Colors.RESET}")
        print(f"{Colors.GREEN}  - RF.golden and DM.golden generated in Testbench/{Colors.RESET}\n")

        # ==================== Stage 2: RTL Simulation ====================
        print(f"{Colors.BOLD}Stage 2: RTL Simulation via Vivado{Colors.RESET}\n")

        vivado_path = find_vivado()
        if vivado_path is None:
            print(f"{Colors.RED}Error: Vivado executable not found.{Colors.RESET}")
            print(f"{Colors.YELLOW}Searched PATH and C:/Xilinx/*/Vivado/bin/ and C:/Xilinx/Vivado/*/bin/{Colors.RESET}")
            print(f"{Colors.YELLOW}Options:{Colors.RESET}")
            print(f"{Colors.YELLOW}  1. Add Vivado bin directory to PATH and re-run this script.{Colors.RESET}")
            print(f"{Colors.YELLOW}  2. Open Vivado GUI, run the simulation manually, then re-run this script.{Colors.RESET}")
            print(f"{Colors.YELLOW}     (Stage 3 verification can still run if RF.out/DM.out already exist){Colors.RESET}")
        else:
            script_tcl = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Script.tcl')
            if not os.path.exists(script_tcl):
                print(f"{Colors.RED}Error: Script.tcl not found at {script_tcl}{Colors.RESET}")
                sys.exit(1)

            if not run_simulation(script_tcl, vivado_path):
                print(f"\n{Colors.RED}RTL simulation failed. Cannot proceed to verification.{Colors.RESET}")
                print(f"{Colors.YELLOW}If you have pre-existing RF.out/DM.out you want to verify, answer 'y' below.{Colors.RESET}")

        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ Stage 2 completed.{Colors.RESET}\n")

        # ==================== Stage 3: Verification ====================
        print(f"{Colors.BOLD}Stage 3: Verification{Colors.RESET}\n")

        result = verify()
        sys.exit(0 if result['success'] else 1)

    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}Operation interrupted by user.{Colors.RESET}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Error: {e}{Colors.RESET}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
