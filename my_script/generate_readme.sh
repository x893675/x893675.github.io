#!/bin/bash
cat README.md.template > README.md
./my_script/print_post_metadata.py >> README.md
