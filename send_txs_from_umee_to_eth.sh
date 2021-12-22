#!/bin/bash
source ~/.bash_profile

amount_to_send="" # if string is empty then amount will be tx_number, eg. 53th tx will send 53uumee
txs_to_send="50"
delay_between_txs="15"

eth_addr=$UMEE_WALLET_ETH_TASK
umee_wallet_name=$UMEE_WALLET_TASK
umee_wallet_addr=$UMEE_WALLET_ADDR_TASK
umee_chain=$UMEE_CHAIN
umee_pass=$UMEE_PASS
gas_flags="--gas=auto --gas-adjustment=1.4"
extra_flags=""  # node, home etc

log_file="${HOME}/$(date +"%y-%m-%d_%H-%M-%S")_umee_to_eth.txt"


for (( i=1; i<=$txs_to_send; i++ )); do
  if [[ "$i" -ne "1" ]]; then
      sleep $delay_between_txs
  fi

  # path to seq differ for each project; examples: `.base_account.sequence`, `.sequence`
  seq=$(umeed q account $umee_wallet_addr $extra_flags -o=json | jq -r .sequence)
  error_code="32"

  if [ -z "$amount_to_send" ]; then
    amount_to_send=$i
  fi

  while [[ "$error_code" != "0" ]]; do
    # umeed tx peggy send-to-eth [eth-dest-addr] [amount] [bridge-fee] [flags]
    result=$(echo $umee_pass | umeed tx peggy send-to-eth $eth_addr ${amount_to_send}uumee 1uumee --from=$umee_wallet_name --chain-id=$umee_chain $gas_flags $extra_flags -y -o=json)
    error_code=$(echo $result | jq .code)

    if [[ "$error_code" == "32" ]]; then
      # get account sequence from the failed tx raw_log
      seq=$(echo ${result} | jq .raw_log | awk '{print substr($5, 1, length($5)-1)}')
      echo "wrong sequence; right sequence is:" $seq & sleep 1
    elif [[ "$error_code" != "0" ]]; then
      # path to seq differ for each project; examples: `.base_account.sequence`, `.sequence`
      seq=$(umeed q account $umee_wallet_addr $extra_flags -o=json | jq -r .sequence)
      echo "error code:" $error_code & sleep 1
    else
      tx_hash=$(echo $result | jq -r .txhash)
      echo "successful tx! $tx_hash" && echo $tx_hash >> $log_file
    fi
  done
done
