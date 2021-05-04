sepolicy() {
scontext=$(grep "avc:" $1 | grep "denied" | sed -n -e 's/^.*scontext=//p' | cut -d: -f3 | sort  | uniq)
for i in $scontext; do
  permission=''
  tclass=$(grep $i $1 | sed -n -e 's/^.*tclass=//p' | cut -d" " -f1 | sort | uniq)
  for d in $tclass; do
    rm -rf temp.txt
    tcontext=$(grep $i $1 | grep "$d" | sed -n -e 's/^.*tcontext=//p' | cut -d: -f3 | sort | uniq)
    tcontext="${tcontext// /}"
    de=$(grep $i $1 | grep "$tcontext" |grep "$d" | sed -n -e 's/^.*{ //p' | cut -d" " -f1 | sort | uniq)
    for c in $de; do
      echo $c >> temp.txt
    done
    permission=$(sort temp.txt | uniq | tr '\n' ' ')

    if [ "${permission: -1}" != " " ]; then
      permission="$permission "
    fi

    for r in $tcontext; do
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

if [ ! -d sepolicy ]; then
mkdir sepolicy
fi

if [ ! -d sepolicy/vendor ]; then
mkdir sepolicy/vendor
fi

for opt in $@; do
if [ $opt == "--clean" ]; then
echo "Cleaning old sepolicy"
rm -rf sepolicy/vendor/*.te
fi
done

sepolicy $1
rm -rf temp.txt
