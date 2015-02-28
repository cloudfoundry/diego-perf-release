scripts_dir=$(dirname $0)

function fast_bosh () {
  BUNDLE_GEMFILE=$scripts_dir/bosh.Gemfile bundle exec bosh $@
}

