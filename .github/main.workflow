workflow "Test" {
  on = "push"
  resolves = ["docker://swift"]
}

action "docker://swift" {
  uses = "docker://swift"
  args = "swift test"
}
