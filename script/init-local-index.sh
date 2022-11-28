#!/bin/bash

set -e
set -x

this_file="$(realpath -s "${BASH_SOURCE[0]}")"
this_dir="${this_file%/*}"
project_root="${this_dir%/*}"

cd "$project_root"

if [ -d tmp/index-bare ]; then
    echo "tmp/index-bare already exists, exiting"
    exit 0
fi

mkdir -p tmp
rm -rf tmp/index-bare tmp/index-tmp

echo "Initializing repository in tmp/index-bare..."
git -c init.defaultBranch=master init  -q --bare tmp/index-bare

echo "Creating temporary clone in tmp/index-tmp..."
curl -sSLf -o index.zip https://github.com/rust-lang/crates.io-index/archive/refs/heads/master.zip
unzip index.zip
mv crates.io-index-master tmp/index-tmp
git -c init.defaultBranch=master init -q tmp/index-tmp
pushd tmp/index-tmp
echo '{
  "dl": "http://localhost:8888/api/v1/crates",
  "api": "http://localhost:8888/"
}' > config.json
git add .
git commit -qm 'Initial commit'
git remote add origin file://"$project_root"/tmp/index-bare
git push -q origin master -u > /dev/null
popd

# Remove the temporary checkout.
# Need to retry multiple times because some lingering process might be locking
# a file within the .git directory, which would prevent the cleanup.
for ((i=0; i < 8; i++)); do
  if rm -rf tmp/index-tmp; then
    break
  else
    sleep 2
  fi
done
if [ -d tmp/index-tmp ]; then
  >&2 echo "Failed to clean up tmp/index-tmp"
  exit 1
fi

# Allow the index to be exported via HTTP during local development
touch tmp/index-bare/git-daemon-export-ok

cat - <<-EOF
Your local git index is ready to go!

Please refer to https://github.com/rust-lang/crates.io/blob/master/docs/CONTRIBUTING.md for more info!
EOF
