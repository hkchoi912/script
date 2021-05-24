#!/bin/bash

aa=$(sed -rn 's/([0-9].+),0.95.+$/\1/p' $1 | head -n 1)

echo $aa