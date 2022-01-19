#!/bin/bash
source ~/.bash_profile

MIN_BALANCE_TO_SAVE=1000

COS_BIN="umeed"
COS_DENOM="uumee"
COS_PASS=$UMEE_PASS
COS_CHAIN=$UMEE_CHAIN
COS_VALOP=$UMEE_VALOP
COS_WALLET=$UMEE_WALLET_VAL
COS_WALLET_ADDR=$UMEE_ADDR_VAL
COS_FEES="--fees=10${COS_DENOM}"

LOG_PATH="${HOME}/${COS_BIN}_staking.log"

while true; do
  # run delegation every new block
  current_block=$(umeed status 2>&1 | jq -r .SyncInfo.latest_block_height)
  while [[ ${current_block} -le ${last_block} ]]; do
    echo "waiting next block: $((current_block + 1))"
    sleep 0.1
    current_block=$(umeed status 2>&1 | jq -r .SyncInfo.latest_block_height)
  done
  
  echo ${COS_PASS} | $COS_BIN tx distribution withdraw-rewards ${COS_VALOP} --from=${COS_WALLET} --chain-id=${COS_CHAIN} --commission ${COS_FEES} -y > /dev/null 2>&1
  balance_before=$($COS_BIN query bank balances ${COS_WALLET_ADDR} --chain-id=${COS_CHAIN} -o=json | jq -r ".balances[] |  select(.denom==\"uumee\") | .amount")
  amount_to_delegate=$((balance_before - MIN_BALANCE_TO_SAVE))
  echo "$(date) block: ${current_block}"
  echo "current balance: ${balance_before} to delegate: ${amount_to_delegate}"

  if [[ ${amount_to_delegate} -gt 0 ]]; then
    error_code="32";
    # path to seq differ for each project; examples: `.base_account.sequence`, `.sequence`
    seq=$($COS_BIN q account ${COS_WALLET_ADDR} -o=json | jq -r .sequence)

    while [[ "$error_code" == "32" ]]; do
      result=$(echo ${COS_PASS} | $COS_BIN tx staking delegate ${COS_VALOP} ${amount_to_delegate}${COS_DENOM} --from=${COS_WALLET} --chain-id=${COS_CHAIN} ${COS_FEES} -s=${seq} -y -o=json)
      error_code=$(echo ${result} | jq .code)

      if [[ "$error_code" == "32" ]]; then
        # get account sequence from the failed tx raw_log
        seq=$(echo ${result} | jq .raw_log | awk '{print substr($5, 1, length($5)-1)}')
        echo "wrong sequence; right sequence is:" $seq
      elif [[ "$error_code" == "0" ]]; then
        echo "success! tx hash $(echo $result | jq -r .txhash)"
        last_block=$current_block
      else
        echo ${result} | jq .raw_log
      fi
    done
  
  else
    echo "TOO LITTLE BALANCE FOR DELEGATION"
    last_block=$current_block
  fi
done
