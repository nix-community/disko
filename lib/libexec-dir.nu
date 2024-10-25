export def main []: nothing -> path {
    # $env.FILE_PWD contains the file of the script (disko.nu), not this module
    let libexec_dir = $env.FILE_PWD
    $libexec_dir
}