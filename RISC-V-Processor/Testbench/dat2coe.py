import sys
import os

def dat_to_coe(input_path, output_path, depth=1024):
    bytes_list = []

    with open(input_path, 'r', encoding='latin-1') as f:
        for line in f:
            line = line.strip()
            # 跳過空行和註解
            if not line or line.startswith('//'):
                continue
            # 只取 2 字元的 hex byte
            if len(line) == 2:
                bytes_list.append(int(line, 16))

    # 每 4 bytes 組成一個 32-bit word (big-endian: byte0=MSB)
    words = []
    for i in range(0, len(bytes_list), 4):
        chunk = bytes_list[i:i+4]
        if len(chunk) < 4:
            chunk += [0] * (4 - len(chunk))  # 補 0
        word = (chunk[0] << 24) | (chunk[1] << 16) | (chunk[2] << 8) | chunk[3]
        words.append(word)

    # 補齊到 depth
    while len(words) < depth:
        words.append(0x00000013)  # NOP

    with open(output_path, 'w') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        for idx, word in enumerate(words):
            if idx < len(words) - 1:
                f.write(f'{word:08X},\n')
            else:
                f.write(f'{word:08X};\n')

    print(f'Done: {len(bytes_list)} bytes → {len(words)} words')
    print(f'Output: {output_path}')

if __name__ == '__main__':
    base = os.path.dirname(os.path.abspath(__file__))
    input_file  = os.path.join(base, 'IM.dat')
    output_file = os.path.join(base, 'IM.coe')
    dat_to_coe(input_file, output_file)
