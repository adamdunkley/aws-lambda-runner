# AWS Lambda Test Harness

A bash script script for easily running AWS Lambda functions (node packages), seeing the resulting log entry and cleaning up the test afterward.

## Usage

```
bash lambda_execution_role_arn=$YOUR_ARN script_directory=/package/path runner.sh 
```

Options include:

* `quiet=0` - If switched to `1`, removes all output except the script log
* `script_directory=./` - The directory in which the script will run. Defaults to the current directory which is almost never what you actually want
* `input_file_name=test-input.json` - The name of the test input JSON file (relative to the test script directory) you'd like to pass to the runner
* `handler_name=index.handler` - The handler that Lambda will execute, format: {file_name}.{exported_function_name} 
* `region=eu_west_1` - The AWS region to the run it in (defaults to my region because I am a narcissist)
* `script_timeout=60` - The timeout for the execution (affects expense)
* `script_max_memory=128` – The max memory (in MB) that the execution can go to (affects expense)
* `function_prefix=test` – The prefix given to the random name the created Lambda function is given (in case you have lots of these tests running in parallel and are worried about the entropy of the random name or something)
* `npm_install=0` - (Re-)install node packages every time (you need package.json set up and `npm install` on your system)

Note: Do not hammer `ctrl^c` to kill the application as you'll probably kill the cleanup that deletes the lambda function (creating lots of redundant scripts in your Lambda function list). Just press it once and wait.

## Contributing

This is released under a GNU General Public License. If you want to contribute please fork and make a pull request, my Bash skills suck and there's plenty that still needs to be done to make this an even better experience. Thanks!
