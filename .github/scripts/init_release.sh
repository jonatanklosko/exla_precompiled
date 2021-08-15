#!/bin/bash

set -ex

tag=$(mix build.release_tag)

if gh release list | grep $tag; then
  nif_filename=$(mix build.release_nif_filename)

  if gh release view $tag | grep $nif_filename; then
    echo "::set-output name=continue::false"
  else
    echo "::set-output name=continue::true"
  fi
else
  gh release create $tag --notes ""
  echo "::set-output name=continue::true"
fi
