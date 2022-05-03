#!/usr/bin/python3
import os
import re

regex_usb_dir = re.compile('\\d+-\\d+')
regex_alveo = re.compile('A-U2[05]0-[AP]64G')

known_serial_list = {
    '007F7001': {
        'port': ':1.1',
        'name': 'EK-U1-VCU118-G'
    },
    '40514E02E064C49411E72DD9F0AED86': [{
        'port': ':1.0',
        'name': 'EK-U1-ZCU106-G PS_UART0'
    }, {
        'port': ':1.1',
        'name': 'EK-U1-ZCU106-G PS_UART1'
    }, {
        'port': ':1.2',
        'name': 'EK-U1-ZCU106-G PL_UART'
    }]
}

serial_sort_list = {
    '21290606R005': 0,  # U200
    '21290605L00F': 1,  # U200
    '2133040CT00G': 0,  # U250
    '2133040CT001': 1,  # U250
    '2133040CT02P': 2,  # U250
    '2133040CM02N': 3,  # U250 -> BROKEN
    '007F7001': 0,  # VCU118
}


def find_index(data):
    serial = data['serial']

    if serial in serial_sort_list:
        return serial_sort_list[serial]
    else:
        return 100


def readfile(path):
    with open(path, 'r') as f:
        return f.read()


def get_tty_name(dir):
    tty = [
        f for f in os.listdir(dir)
        if os.path.isdir(os.path.join(dir, f)) and f.startswith('tty')
    ]

    if len(tty) != 1:
        return None

    return tty[0].strip()


def main():
    usb_bus = '/sys/bus/usb/devices'
    usb_dir = [
        f for f in os.listdir(usb_bus)
        if os.path.islink(os.path.join(usb_bus, f)) and regex_usb_dir.match(f)
    ]

    device_list = []

    for usb in usb_dir:
        cur_path = os.path.join(usb_bus, usb)
        product_path = os.path.join(cur_path, 'product')
        serial_path = os.path.join(cur_path, 'serial')

        if os.path.isfile(product_path):
            product = readfile(product_path).strip()
        else:
            continue

        if os.path.isfile(serial_path):
            serial = readfile(serial_path).strip()
        else:
            continue

        # Check product is known
        if regex_alveo.match(product):
            # Alveo uses third port as UART from FPGA
            port_dir = os.path.join(cur_path, usb + ':1.2')
        elif product.startswith('CAMEL'):
            # Our QSFP to UART adapter
            port_dir = os.path.join(cur_path, usb + ':1.0')
        elif serial in known_serial_list:
            info = known_serial_list[serial]

            if isinstance(info, dict):
                product = info['name']  # Override product info
                port_dir = os.path.join(cur_path, usb + info['port'])
            elif isinstance(info, list):
                product = [f['name'] for f in info]
                port_dir = [
                    os.path.join(cur_path, usb + f['port']) for f in info
                ]
        else:
            continue

        # Check tty name
        if not isinstance(port_dir, list):
            port_dir = [port_dir]
            product = [product]

        for i, dir in enumerate(port_dir):
            tty = get_tty_name(dir)

            if tty is not None:
                # Push result
                device_list.append({
                    'product': product[i],
                    'serial': serial,
                    'tty': tty
                })

    if len(device_list) == 0:
        print('No known tty ports found')
    else:
        # Sort
        device_list.sort(key=find_index)

        # Print
        for device in device_list:
            print(
                f'{device["product"]}: {device["serial"]}\n  {device["tty"]}')

    return 0


if __name__ == '__main__':
    exit(main())

