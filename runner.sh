#!/bin/bash
exec 3>&1
exec 4>&2
if (( $quiet )); then
  exec 1>/dev/null
  exec 2>/dev/null
fi
if [ ! -n "$lambda_execution_role_arn" ]; then 
  echo "Must provide lambda_exucution_role_arn variable"
  exit 1
fi
if [ -n "$script_directory" ]; then
  cd $script_directory
fi
[ -n "$npm_install" ] || npm_install=0
[ -n "$input_file_name" ] || input_file_name="test-input.json"
[ -n "$handler_name" ] || handler_name="index.handler"
[ -n "$region" ] || region="eu-west-1"
[ -n "$script_timeout" ] || script_timeout="60"
[ -n "$script_max_memory" ] || script_max_memory="128"
[ -n "$function_prefix" ] || function_prefix="test"
function_name=$function_prefix$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
log_group_name="/aws/lambda/"$function_name
all_log_names_func () { aws logs describe-log-streams --log-group-name $log_group_name --output text --query "logStreams[*].{logStreamName:logStreamName,creationTime:creationTime}" 2> /dev/null; }
last_log_name_func () { echo "$(all_log_names_func)" | sort | tail -n1 | cut -f2; }
if [ $npm_install -ne 0 ]; then 
  echo "Installing node packages"
  rm -rf ./node_modules
  npm install
  [ $? -ne 0 ] && exit 1
fi
echo "Compressing package"
zip -rq "/tmp/package-"$function_name".zip" *
[ $? -ne 0 ] && exit 1
cleanup_lambda () {
  echo "Cleaning up lambda function" 
  aws lambda delete-function \
    --function-name $function_name \
    --region $region
  rm "/tmp/package-"$function_name".zip"
}
trap cleanup_lambda EXIT
echo "Uploading and running lambda function"
aws lambda upload-function \
  --region $region \
  --function-name $function_name  \
  --function-zip "/tmp/package-"$function_name".zip" \
  --role $lambda_execution_role_arn \
  --mode "event" \
  --handler $handler_name \
  --runtime "nodejs" \
  --timeout $script_timeout \
  --memory-size $script_max_memory
[ $? -ne 0 ] && exit 1
aws lambda invoke-async \
  --function-name $function_name \
  --region $region \
  --invoke-args $input_file_name
[ $? -ne 0 ] && exit 1
response=""
start=$SECONDS
while true; do
  last_log_name="$(last_log_name_func)"
  if [ "$last_log_name" != "" ]; then
    line_count=0
    while true; do
      response="$(aws logs get-log-events \
        --log-group-name "$log_group_name" \
        --log-stream-name $last_log_name \
        --output text \
        --query 'events[*].message')"
      [ $? -ne 0 ] && exit 1
      new_line_count=$(echo "$response" | wc -l)
      current_new_line_count=$(expr $new_line_count - $line_count)
      if [ $current_new_line_count -gt 0 ]; then
        echo "$response" | tail -n$current_new_line_count 1>&3 2>&4
        line_count=$new_line_count
        if [[ $response == *"REPORT RequestId"* ]]; then
          exit
        fi
      fi
      sleep 1
    done
  fi
  echo -en "\rWaiting for log to start ("$(( SECONDS - start ))" seconds elapsed)"
  sleep 1
done
