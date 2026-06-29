# shellcheck shell=bash
# Big integer helpers for wei values (bash $(( )) overflows above ~9e18).

wei_div_gwei() {
  local wei="${1:?wei required}"
  node -e "console.log((BigInt(process.argv[1])/1000000000n).toString())" "${wei}"
}

wei_sub() {
  local a="${1:?minuend required}"
  local b="${2:?subtrahend required}"
  node -e "console.log((BigInt(process.argv[1])-BigInt(process.argv[2])).toString())" "${a}" "${b}"
}

wei_gt() {
  local a="${1:?left required}"
  local b="${2:?right required}"
  node -e "process.exit(BigInt(process.argv[1]) > BigInt(process.argv[2]) ? 0 : 1)" "${a}" "${b}"
}
