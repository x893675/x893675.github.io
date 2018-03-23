#!/bin/bash
cat ../README.md.template > ../README.md
./print_post_metadata.py >> ../README.md
