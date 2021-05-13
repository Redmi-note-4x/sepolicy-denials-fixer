# Sepolicy Denials Fixer

Generate Fixes for your SELinux Denials.
Generates Fixes at sepolicy/vendor/*.te files

## Comands
`. sepolicy.sh File1 File2 .. {options}`

**Options:-** <br>
`-path={dir}`                : allows to write sepolicy fixes at custom path <br>
`--clean`                    : Removes old sepolicy and start with clean <br>
`-s scontext1,scontext2..`   : Only resolve denials for given scontexts <br>
`-r scontext1,scontext2..`   : Ignores denials for given scontexts
<br>

Use , for multiple scontexts in -r and -s
Example `-s init,zygote`
