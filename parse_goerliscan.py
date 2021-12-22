"""
Register at https://etherscan.io and get ur api key at /myapikey which will work for all test networks.
Need to install third party library `pip install requests`; sorry for inconvenience.
Input your eth address and date from which incoming tx must be parsed; keep date format "y-m-d H:M:S" please.

PARSE_OUTGOING=True will work only if you have file with hashes,
which you most likely saved during txs generation ;)
Otherwise put False and no attempt to check PATH_TO_ETH_HASHES will be made.

PRINT_INCOMING_TXS_WITH_VALUES simply prints sorted by value incoming txs,
which is useful if txs may be distinguish by value.
"""

import requests # pip install requests
from time import sleep
from datetime import datetime

MY_ETH_ADDR = ''
API_KEY = ''  # register here and get the key https://etherscan.io/myapikey
INCOMING_TXS_DATE_FROM = '2021-12-22 15:00:00'

PARSE_OUTGOING = True
PATH_TO_ETH_HASHES = r'umee_eth_to_cos.txt'  # one tx hash per line
PRINT_INCOMING_TXS_WITH_VALUES = False


ENDPOINT = 'https://api-goerli.etherscan.io/api'
HEADERS = {'User-Agent': 'UR MOM'}  # 403 response with empty user-agent
CONTRACT_ADDR = '0xe54fbaecc50731afe54924c40dfd1274f718fe02'    # umee token contract


def get_txs(address:str, offset=0) -> dict:
    params = {
        'module': 'account', 'action': 'tokentx',
        'startblock': '0', 'endblock': '99999999', 'page': '1',
        'address': address.lower(), 'offset': offset, 'sort': 'desc',
        'apikey': API_KEY,
    }

    for _ in range(6):
        try:
            r = requests.get(ENDPOINT, params=params, headers=HEADERS, timeout=5)
            if r.status_code == 200:
                return r.json()
            print(r)
            r.raise_for_status()
        except requests.ReadTimeout as req_timeout:
            sleep(11)
    return {}


def main():
    my_eth_addr = MY_ETH_ADDR.lower()
    if PARSE_OUTGOING:
        with open(PATH_TO_ETH_HASHES) as fh:
            umee_to_eth_hashes = [x.strip().lower() for x in fh.readlines() if x.strip()]

    # get all txs for the account from the goerli.etherscan.io
    txs_data = get_txs(my_eth_addr)
    if 'result' not in txs_data:
        exit('no tx was found')

    # parse and sort data from all txs
    incoming_txs_all = []
    outgoing_hashes = []
    for tx in txs_data['result']:
        if tx['from'] == my_eth_addr:
            outgoing_hashes.append(tx['hash'])
        elif tx['to'] == my_eth_addr and tx['contractAddress'] == CONTRACT_ADDR:
            incoming_txs_all.append(tx)

    if PARSE_OUTGOING:
        # check if our stored outgoing txs hashes can be found in all txs hashes
        all_eth_umee_found = True
        for tx_hash in umee_to_eth_hashes:
            if tx_hash not in outgoing_hashes:
                print(f"can't find {tx_hash}")
                all_eth_umee_found = False
        if all_eth_umee_found:
            print(f"All {len(umee_to_eth_hashes)} eth->umee txs were found on goerli.etherscan.io")

    # find all incoming txs for given token and not older than specific time
    incoming_txs_filtered = []
    for tx in incoming_txs_all:
        tx_time = str(datetime.fromtimestamp(int(tx['timeStamp'])))
        if tx_time >= INCOMING_TXS_DATE_FROM:
            incoming_txs_filtered.append({'date': tx_time, 'value': tx['value'], 'token': tx['tokenName']})

    if PRINT_INCOMING_TXS_WITH_VALUES:
        # optionally print each founded tx from step above
        for tx in sorted(incoming_txs_filtered, key=lambda x: int(x['value'])):
            print(f"{tx['date']} value: {tx['value']:>8}{tx['token']}")
    print(f"from {INCOMING_TXS_DATE_FROM} received: {len(incoming_txs_filtered)} txs")


if __name__ == '__main__':
    main()
