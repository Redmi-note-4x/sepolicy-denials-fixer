sepolicy() {
scontext=$(grep "avc:" $1 | grep "denied" | sed -n -e 's/^.*scontext=//p' | cut -d: -f3 | sort  | uniq)

for i in $scontext; do
  scon_check=0
  rcheck=0
  if [ ! -z "$scon" ]; then
    for j in $scon; do
      if [ $j == $i ]; then
	scon_check=1
	break
      fi
    done
  elif [ ! -z "$rcon" ]; then
    for j in $rcon; do
      if [ $j == $i ]; then
	rcheck=1
	break
      fi
    done
    if [ $rcheck -eq 0 ]; then
      scon_check=1
    else
      scon_check=0
    fi
  fi
  if [ $scon_check -eq 0 ] && ([ ! -z "$scon" ] || [ ! -z "$rcon" ]); then
  continue
  fi
  permission=''
  tclass=$(grep $i $1 | sed -n -e 's/^.*tclass=//p' | cut -d" " -f1 | sort | uniq)
  for d in $tclass; do
    rm -rf temp.txt
    tcontext=$(grep $i $1 | grep "tclass=$d" | sed -n -e 's/^.*tcontext=//p' | cut -d: -f3 | sort | uniq)
    tcontext="${tcontext// /}"
    for r in $tcontext; do
      rm -rf temp.txt
      de=$(grep $i $1 | grep "$r" |grep "$d" | sed -n -e 's/^.*{ //p' | cut -d" " -f1 | sort | uniq)
      for c in $de; do
        echo $c >> temp.txt
      done
      permission=$(sort temp.txt | uniq | tr '\n' ' ')

      if [ "${permission: -1}" != " " ]; then
        permission="$permission "
      fi

      if [ ! -f sepolicy/vendor/$i.te ]; then
	echo "#============= $i ==============" >> sepolicy/vendor/$i.te
      fi
      perm=( $permission  )
      present_check=$(grep "allow $i $r:$d" sepolicy/vendor/$i.te)
      if [ ! -z "$(echo "$r" | grep prop)" ]; then
        if [ ! -z "$(echo "$permission" | grep read)" ]; then
          write="get_prop($i, $r);"
	elif [ ! -z "$(echo "$permission" | grep set)" ]; then
          write="set_prop($i, $r);"
	else
          write="allow $i $r:$d { $permission};"
	fi
      elif [ $(echo ${#perm[@]}) -eq 1 ]; then
          permission=${permission::-1}
          write="allow $i $r:$d $permission;"
      else
	  write="allow $i $r:$d { $permission};"
      fi
      if [ -f sepolicy/vendor/$i.te ] && [ ! -z "$present_check" ] && [ "$present_check" != "$write" ]; then
        if [ ! -z "$(echo "$present_check" | grep '{')" ]; then
          new_permission=$(echo "$present_check" | cut -d"{" -f2 | cut -d"}" -f1 )
        else
          new_permission=$(echo "$present_check" | cut -d" " -f4 | cut -d";" -f1 )
        fi
        for u in $new_permission; do
	  echo $u >> temp.txt
        done
	permission=$(sort temp.txt | uniq | tr '\n' ' ')
	write="allow $i $r:$d { $permission};"
	sed -i -e "s/${present_check}/${write}/g" sepolicy/vendor/$i.te
	echo "$write"
      else
        check=$(grep "$write" sepolicy/vendor/$i.te)
        if [ -z "$check" ]; then
          echo "$write" >> sepolicy/vendor/$i.te
          echo "$write"
        else
        echo "skipping, $write already present."
        fi
      fi
    done
  done
done
}

error=0
scon=""
rcon=""

if [ ! -d sepolicy ]; then
mkdir sepolicy
fi
if [ ! -d sepolicy/vendor ]; then
mkdir sepolicy/vendor
fi

echo "-"
echo "Sepolicy Fixer v1"
echo "by Kingsman44"
echo "-"
echo ""

# Options
opt=$@
if [ ! -z "$(echo "$opt" | grep -e '--help')" ]; then
echo "Usage: "
echo ". sepolicy.sh file1 file2 ... { options } "
echo ""
echo "Options"
echo "--clean                    : Removes old sepolicy and start with clean"
echo "-s scontext1,scontext2..   : Only resolve denials for given scontexts"
echo "-r scontext1,scontext2..   : Ignores denials for given scontexts"
echo ""
echo "Use , for multiple scontexts in -r and -s"
echo "Example: -s init,zygote"
error=1
fi

if [ ! -z "$(echo "$opt" | grep -e '-s')" ] && [ $error -eq 0 ]; then
scon="$(echo "$opt" | sed -n -e 's/^.*-s //p' | cut -d' ' -f1)"
scon="$(echo $scon | tr "," " ")"
if [ -z "$scon" ] || [ "${scon:0:1}" == "-" ]; then
echo "Error:"
echo "-s option used but no scontext Defined."
echo "use --help for more information"
error=1
else
echo "-s option used"
echo "only fixes for $scon will be generated."
echo ""
fi
fi

if [ ! -z "$(echo "$opt" | grep -e '-r')" ] && [ $error -eq 0 ]; then
rcon="$(echo "$opt" | sed -n -e 's/^.*-r //p' | cut -d' ' -f1)"
rcon="$(echo $rcon | tr "," " ")"
if [ -z "$rcon" ] || [ "${rcon:0:1}" == "-" ]; then
echo "Error:"
echo "-r option used but no scontext Defined."
echo "use --help for more information"
error=1
elif [ ! -z "$scon" ]; then
echo "Error:"
echo "-r option and -s can't used simultaneosly."
echo "use --help for more information"
error=1
else
echo "-r option used"
echo "$rcon fixes will be ignored."
echo ""
fi
fi

if [ ! -z "$(echo "$opt" | grep -e '--clean')" ] && [ $error -eq 0 ]; then
rm -rf sepolicy/vendor/*.te
echo "-Cleaning Previous Sepolicy Fixes"
echo ""
fi

for file in $@; do
if [ -f $file ] && [ $error -eq 0 ]; then
echo "-Selinux Fixes From $file"
echo ""
sepolicy $file
rm -rf temp.txt
echo ""
fi
done
