#!/bin/bash
source ~/.bash_profile

amount_to_send="1"
tx_to_send="50"
delay_between_tx="15"

umee_erc20_contract="0xe54fbaecc50731afe54924c40dfd1274f718fe02"
umee_wallet_addr=$UMEE_WALLET_ADDR_TASK
eth_rpc=$ETH_RPC
eth_pk=$ETH_PK_TASK

log_file="${HOME}/$(date +"%y-%m-%d_%H-%M-%S")_eth_to_umee.txt"

for (( i=1; i<=$tx_to_send; i++ )); do
  if [[ "$i" -ne "1" ]]; then
      sleep $delay_between_tx
  fi

  # peggo bridge send-to-cosmos [token-address] [recipient] [amount] [flags]
  result=$(peggo bridge send-to-cosmos $umee_erc20_contract $umee_wallet_addr $amount_to_send --eth-pk=$eth_pk --eth-rpc=$eth_rpc --cosmos-chain-id=$umee_chain 2>&1)

  if [ -z "$(echo $result | grep -o successfully)" ]; then
    # something went wrong
    echo "$result"
  else
    echo "successful tx!" $(echo $result | grep -o 'Transaction: 0x.*' | awk '{printf $2}')
    echo $(echo $result | grep -o 'Transaction: 0x.*' | awk '{printf $2}') >> $log_file
  fi
done
