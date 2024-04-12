# ci-bot
Designed for remote project management. Allows you to upload assemblies to TestFlight using sh scripts and fastlane
# Setup
1. [Create a Telegram bot](https://core.telegram.org/bots#3-how-do-i-create-a-bot)
2. Change the value of `my_token` to the bot token in the BotService file
```swift
public let botId: String = "my_token"
```
3. In the root of your project, you need to create a `ci_scripts` folder
4. In the `ci_scripts` folder, create `ci_upload.sh` file to upload via ci bot:
```bash
#!/bin/bash

branch=($1)
version=($2)
build=($3)
targets=($4)

targetsString=${targets[@]}

cd ../

git restore . || exit 1
if [ "${PIPESTATUS[0]}" != 0 ]; then
    echo 'gitdiscardall failed'
    exit 1
fi

git checkout $branch || exit 1
if [ "${PIPESTATUS[0]}" != 0 ]; then
    echo 'gitcheckout failed'
    exit 1
fi

git pull origin $branch || exit 1
if [ "${PIPESTATUS[0]}" != 0 ]; then
    echo 'gitpull failed'
    exit 1
fi

cd ci_scripts

sh upload.sh $version $build "$targetsString"
```
4. In the `ci_scripts` folder, create `upload.sh` file to upload via terminal without using git:
```bash
#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ]
then
   echo "usage: sh upload.sh [\"1.0\"] [\"1\"] [\"MyTarget1 MyTarget2\"] [sync]";
   exit 0;
fi

targets=($3)
processType=($4)

if [ $targets == "All" ]
then
targets=(MyTarget1 MyTarget2)
fi

# Upload
targetsString=${targets[@]}

echo "⚙️ Building: $targetsString"
echo "📱 Version: $1"
echo "📱 Build: $2"

bundle install
if [ $processType == "sync" ]
then
bundle exec fastlane uploadSync schemes:"$targetsString" externalGroup:"$externalGroup"
else
bundle exec fastlane uploadAsync schemes:"$targetsString" externalGroup:"$externalGroup"
fi
```
# Run
- The launch is carried out through the Xcode development environment or through the terminal with the `swift run` command from the ci-bot folder
- After launching the project on the build machine, run the `/start` command in the Telegram bot
- Configuration files, settings, and a list of users are created in the `Documents` folder.
- To use the bot, you need to allow access to the build machine
- To allow access to the Telegram bot, you need to change the value of the `isAvailable` parameter from `false` to `true` for the desired user in the `users.json` file
- After you allow the user to use the Telegram bot, the following commands will be available to you:
```
/help, /start - see the list of commands
/setconfig - change the current config
/getconfig - display the current config

# Commands for interacting with git
/gitcheckout - switch to a branch
/gitfetch - fetch commits
/gitpull - pull commits
/gitdiscardall - discard all changes
/gitstatus - check status

# Commands for interacting with project processes:
/upload - archive builds in testflight
/cancel - cancel the current process
/status - get the status of the current process
/terminalcommand - execute any command in the terminal
```
