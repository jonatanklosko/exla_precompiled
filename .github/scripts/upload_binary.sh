#!/bin/bash

set -ex

tag=$(mix build.release_tag)
nif_filename=$(mix build.release_nif_filename)
build_nif_path=$(mix build.nif_path)

cp $build_nif_path $nif_filename
gh release upload --clobber $tag $nif_filename
