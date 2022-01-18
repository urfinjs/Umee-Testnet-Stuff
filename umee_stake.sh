#!/bin/bash
source ~/.bash_profile

SLEEP_BETWEEN_DELEGATIONS=0
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
  echo ${COS_PASS} | $COS_BIN tx distribution withdraw-rewards ${COS_VALOP} --from=${COS_WALLET} --chain-id=${COS_CHAIN} --commission ${COS_FEES} -y > /dev/null 2>&1
  balance_before=$($COS_BIN query bank balances ${COS_WALLET_ADDR} --chain-id=${COS_CHAIN} -o=json | jq -r '.balances[0].amount')
  amount_to_delegate=$((balance_before - MIN_BALANCE_TO_SAVE))
  echo "Current Voting Power: $($COS_BIN status 2>&1 | jq -r '.ValidatorInfo.VotingPower')"
  echo "$(date) Balance before: ${balance_before} to delegate: ${amount_to_delegate}"

  if [[ ${amount_to_delegate} -gt 0 ]]; then
    #echo "$(date) Balance before: ${balance_before} to delegate: ${amount_to_delegate}" >> ${LOG_PATH} 2>&1
    error_code="32";
    # path to seq differ for each project; examples: `.base_account.sequence`, `.sequence`
    seq=$($COS_BIN q account ${COS_WALLET_ADDR} -o=json | jq -r .sequence)

    while [[ "$error_code" != "32" ]]; do
      result=$(echo ${COS_PASS} | $COS_BIN tx staking delegate ${COS_VALOP} ${amount_to_delegate}${COS_DENOM} --from=${COS_WALLET} --chain-id=${COS_CHAIN} ${COS_FEES} -s=${seq} -y -o=json)
      error_code=$(echo ${result} | jq .code)

      if [[ "$error_code" == "32" ]]; then
        # get account sequence from the failed tx raw_log
        seq=$(echo ${result} | jq .raw_log | awk '{print substr($5, 1, length($5)-1)}')
        echo "wrong sequence; right sequence is:" $seq
      elif [[ "$error_code" != "0" ]]; then
        echo "error code: $error_code message:" `echo $result | jq .raw_log`
        echo $result | jq >> ${LOG_PATH} 2>&1
      else
        echo $(echo $result | jq -r .txhash)
      fi
    done

    #balance_after=$($COS_BIN query bank balances ${COS_WALLET_ADDR} --chain-id=${COS_CHAIN} -o=json | jq -r '.balances[0].amount')
    #echo "$(date) Balance after:  ${balance_after}"

  else
    echo "TOO LITTLE BALANCE FOR DELEGATION"
  fi
done
