#!/bin/sh

function _printUsage_kgs(){
  echo "Command kgs:"
  echo "Usage: kgs"
  echo "Get service of all namespace"
  echo "A.K.A kubectl get svc"
}
alias kgs='kubectl get svc --all-namespaces'

function _printUsage_kgcs(){
  echo "Command kgcs:"
  echo "Usage: kgcs"
  echo "Get configmaps of all namespace"
  echo "A.K.A kubectl get configmap"
}
alias kgcs='kubectl get configmap --all-namespaces'

function _printUsage_kgn(){
  echo "Command kgn:"
  echo "Usage: kgn"
  echo "Get all nodes of the cluster"
  echo "A.K.A kubectl get nodes"
}
alias kgn='kubectl get nodes'

function _printUsage_kcreate(){
  echo "Command kcreate:"
  echo "Usage: kcreate yamlfile/yamlfolder"
  echo "Create Service/Deployment/Ingress/Configmap/Everything defined in yaml file"
  echo "A.K.A  kubectl create -f"
}
alias kcreate='kubectl create -f '

function _printUsage_kdelete(){
  echo "Command kdelete:"
  echo "Usage: kdelete yamlfile/yamlfolder"
  echo "Delete Service/Deployment/Ingress/Configmap/Everything defined yaml file"
  echo "A.K.A  kubectl delete -f"
}
alias kdelete='kubectl delete -f '

function _setup_opts_args(){
  _reset_ns="true"
  _reset_cont="true"
  _K_args=""
  while [[ ! -z "$1" ]];
  do
    if [[ "$1" = "-n" ]];then
      shift
      _K_namespace="$1"
      _reset_ns="false"
#      echo "DEBUG: Command setup namespace to : ${_K_namespace}"
      shift
    elif [[ "$1" = "-c" ]];then
      shift
      _K_container="$1"
      _reset_cont="false"
#      echo "DEBUG: Command setup container to : ${_K_container}"
      shift
    else
      _K_args="${_K_args}    ${1}"
      shift
    fi
  done

  if [[ "${_reset_ns}" == "true" ]];then
     _K_namespace=""
  fi

  if [[ "${_reset_cont}" == "true" ]];then
     _K_container=""
  fi

}

function _getNamespaceOPT(){
  if [[ -z "${_K_namespace}" ]];then
    echo " --all-namespaces "
  else
    echo " -n ${_K_namespace} "
  fi
}

function _getContainerOPT(){
  if [[ -z "${_K_container}" ]];then
    echo " "
  else
    echo " -c ${_K_container} "
  fi
}

function _printPods(){
  ns=`_getNamespaceOPT`
  for i in $(kubectl get pods ${ns} | awk 'NR>1 {print $2}');do
    echo $i
  done
}

function _printConfigMaps(){
  ns=`_getNamespaceOPT`
  for i in $(kubectl get configmaps ${ns} | awk 'NR>1 {print $2}');do
    echo $i
  done
}

function _print_pickone_message(){
   echo "Please pick one value from the following:"
   for i in $@;do
     echo $i
   done
}

function _getContainer(){
  ns=`_getNamespaceOPT`
 # container=`kubectl get pod $1 ${ns} -o jsonpath='{..containers[?(@.image!="localhost:5000/kubernetes-vault-renew:0.2.1")].name}'`
  if [[ ${#containers[@]} = 1 ]];then
      _K_container=$containers[0]
  elif [[ ${#containers[@]} = 0 ]];then
    _K_container=""
  else
      if [[ ! -z "${_K_container}" ]];then
        for i in $containers;do
            m=`echo $i | grep ${_K_container} | wc -l`
            if [[ "$m" = "1" ]];then
              _K_container=$i
              break
            else
              n=`echo $i | grep "\s${_K_container}\s" | wc -l`
              _K_container=""
              if [[ "$n" = "1" ]];then
              _K_container=$i
              break
              fi
            fi
        done
      fi
  fi
  echo $container
}

function _setup_opts_pod_namespace(){
    pod=$1
    _K_pod=""
    ns=`_getNamespaceOPT`
    IFS=' ' read -r -a pods <<< `kubectl get pods ${ns} | grep $pod | awk '{print $1","$2}'`
    if [[ ${#pods[@]} = 1 ]];then
      echo "Get unique Pod : ${pods[0]##*,}"
      _K_pod=${pods[0]##*,}
      _K_namespace=${pods[0]%%,*}
      return 0
    elif [[ ${#pods[@]} = 0 ]];then
      echo "The pod name you input didn't match any pod existing in ${ns}"
      echo "  Pick one from the following pods and try again"
      _printPods
      return 1
    else
      matched=0
      declare -a narrowMatches
      for i in ${pods[@]};do
        m=`echo $i | grep ",\s*${pod}\s*" | wc -l`
        if [[ $m = 1 ]];then
          narrowMatches[$matched]=$i
          matched=`expr $matched + 1 `
        fi
      done
      if [[ ${#narrowMatches[@]} = 1 ]];then
        _K_pod=${narrowMatches[0]##*,}
        _K_namespace=${narrowMatches[0]%%,*}
        echo "Get unique Pod in namespace ${_K_namespace}: ${pods[0]##*,}"
        return 0
      else
         echo "Multiple pods found for namespace ${ns}"
         _print_pickone_message ${pods[@]}
      fi

    fi
}

function _setup_opts_container(){
  if [[ ! -z $1 ]];then
    _K_pod=$1
  fi

  if [[ ! -z $2 ]];then
    _K_namespace=$2
  fi

  if [[ -z ${_K_pod} ]];then
    echo "No pod specified fot get container"
    return 1
  fi

  ns=`_getNamespaceOPT`
  #containersx=`kubectl get pod ${_K_pod} ${ns} -o jsonpath='{..containers[?(@.image!="localhost:5000/kubernetes-vault-renew:0.2.1")].name}'`
  containersx=`kubectl get pod ${_K_pod} ${ns} -o json | jq -rc ' .spec.containers[] | select(.image |  contains("vault")| not ) | .name ' | awk 'NR > 1 {printf(" ")}{printf $1}'`
  IFS=' ' read -r -a containers <<< ${containersx}
  if [[ ${#containers[@]} = 1 ]];then
      _K_container=${containers[0]}
      echo "Get Unique container: ${_K_container}"
      return 0
  elif [[ ${#containers[@]} = 0 ]];then
      echo "Fail.  No container exists for ${ns} , pod ${_K_pod}"
      _K_container=""
      return 1
  else
      if [[ ! -z "${_K_container}" ]];then
        matched=0
        declare -a matched_containers
        for i in ${containers[@]};do
            m=`echo $i | grep ${_K_container} | wc -l`
            if [[ "$m" = "1" ]];then
              matched_containers[$matched]=$i
              matched=`expr $matched + 1`
            fi
        done

        if [[ ${#matched_containers[@]} = 1 ]]; then
          _K_container=${matched_containers[0]}
          echo "Get Unique container: ${_K_container}"
          return 0
        elif [[ ${#matched_containers[@]} = 0 ]]; then
          echo "Multiple container found for ${ns} , pod ${_K_pod}"
          _print_pickone_message ${containers[@]}
          _K_container=""
          return 1
        else
          narrowMatched=0
          declare -a narrowMatchedContainers
          for i in ${matched_containers[@]}; do
            x=`echo $i | grep ",\s*${_K_container}\s*" | wc -l`
            if [[ "$x" = "1" ]];then
              narrowMatchedContainers[$narrowMatched]=$i
              narrowMatched=`expr $narrowMatched + 1`
            fi
          done
          if [[ ${#narrowMatchedContainers[@]} = 1 ]];then
            _K_container=${narrowMatchedContainers[0]}
            echo "Get Unique container: ${_K_container}"
            return 0
           else
             echo "Multiple container found for ${ns} , pod ${_K_pod}"
             _print_pickone_message ${containers[@]}
             _K_container=""
             return 1
          fi
        fi
      else
        echo "Multiple container found for ${ns} , pod ${_K_pod}"
        _print_pickone_message ${containers[@]}
        _K_container=""
        return 1
      fi
      _K_container=""
      return 1
  fi

}

function _generateGetPodCommand(){
  _setup_opts_args $@
  ns=`_getNamespaceOPT`
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} = 0 ]];then
    echo "kubectl get pods ${ns}"
  elif [[ x${opts[0]} == x-* ]];then
    echo "kubectl get pods ${ns} ${opts[@]}"
  else
    pod=${opts[0]}
    opts[0]=""
    echo "kubectl get pods ${ns} ${opts[@]} | grep $pod"
  fi
}

function _setup_opts_serviceName(){
  _K_yamlsFolder='/var/vols/itom/core/suite-install/itsma/output'
  if [[ ! -z $1 ]];then
    _K_servicename=$1
  fi

  if [[ ! -z $2 ]];then
    _K_yamlsFolder=$2
  fi

  if [[ -z ${_K_servicename} ]];then
    echo ""
    return 1
  fi

  services=`ls -d $_K_yamlsFolder/*/`

  if [[ ${#services[@]} = 0 ]];then
    echo "No service folder fould under ${_K_yamlsFolder}, please specify a correct yamls folder"
    _K_servicename=""
    return 1
  else
    matched=0
    declare -a matches
    index=0
    declare -a existingServices
    for i in ${services[@]};do
      ser=${i%%/}
      ser=${ser##*/}
      existingServices[$index]=$ser
      index=`expr $index + 1`
      m=`echo $ser | grep ${_K_servicename} | wc -l`
      if [[ $m = 1 ]];then
        matches[$matched]=$ser
        matched=`expr $matched + 1`
      fi
    done

    if [[ ${#matches[@]} = 0 ]];then
      echo "No matched service folder fould under ${_K_yamlsFolder}"
      _print_pickone_message ${existingServices[@]}
      _K_servicename=""
      return 1
    elif [[ ${#matches[@]} = 1 ]];then
      _K_servicename=${matches[0]}
      echo "Matched Service folder found: ${_K_servicename}"
      return 0
    else
      narrowMatched=0
      declare -a narrowMatches
      for i in ${matches[@]};do
        n=`echo $i | grep "\s*${_K_servicename}\s*" | wc -l`
        if [[ $m = 1 ]];then
            narrowMatches[$narrowMatched]=$i
            narrowMatched=`expr $narrowMatched + 1`
      fi
      done

      if [[ ${#narrowMatches[@]} = 1 ]];then
        _K_servicename=${narrowMatches[0]}
        echo "Matched Service folder found: ${_K_servicename}"
        return 0
      else
        echo "Multiple service folder fould under ${_K_yamlsFolder}"
        _print_pickone_message ${existingServices[@]}
        _K_servicename=""
        return 1
      fi
    fi
  fi
}

function _getYamlsPath(){
  _K_yamlsFolder='/var/vols/itom/core/suite-install/itsma/output'
  if [[ ! -z $1 ]];then
    _K_servicename=$1
  fi

  if [[ ! -z $2 ]];then
    _K_yamlsFolder=$2
  fi

  echo "${_K_yamlsFolder%%/}/${_K_servicename}/yamls"
}

function _getPodLogPath(){
    if [[ ! -z $1 ]];then
      _K_pod=$1
    fi

    if [[ ! -z $2 ]];then
      _K_baselogfolder=$2
    else
      _K_baselogfolder='/var/vols/itom/itsma'
    fi

    path=''
    for i in $(find ${_K_baselogfolder} -type d -name ${_K_pod}); do
      path=$i
      break
    done
  echo $path
}

function _setup_opts_configmap(){
  if [[ ! -z $1 ]];then
    _K_configmap=$1
  fi

  if [[ ! -z $2 ]];then
    _K_namespace=$2
  fi

  if [[ -z ${_K_configmap} ]];then
    echo "No configmap specified"
    return 1
  fi

  ns=`_getNamespaceOPT`
  IFS=' ' read -r -a configmaps <<< `kubectl get configmaps ${ns} | grep ${_K_configmap} | awk '{print $1","$2}'`
  if [[ ${#configmaps[@]} = 1 ]];then
    echo "Get unique configmap : ${configmaps[0]##*,}"
    _K_configmap=${configmaps[0]##*,}
    _K_namespace=${configmaps[0]%%,*}
    return 0
  elif [[ ${#configmaps[@]} = 0 ]];then
    echo "No configmap exists in ${ns}"
    echo "  Pick one from the following and try again"
    _printConfigMaps
    return 1
  else
    narrowMatched=0
    declare -a narrowMatchedConfigmaps
    for i in ${configmaps[@]}; do
      x=`echo $i | grep ",\s*${_K_configmap}\s*" | wc -l`
      if [[ "$x" = "1" ]];then
        narrowMatchedConfigmaps[$narrowMatched]=$i
        narrowMatched=`expr $narrowMatched + 1`
      fi
    done

    if [[ ${#narrowMatchedConfigmaps[@]} = 1 ]];then
      echo "Get Unique configmap: ${narrowMatchedConfigmaps[0]##*,}"
      _K_configmap=${narrowMatchedConfigmaps[0]##*,}
      _K_namespace=${narrowMatchedConfigmaps[0]%%,*}
      return 0
    else
      echo "Multiple configmaps found for ${ns} , configmap ${_K_configmap}"
       _print_pickone_message ${configmaps[@]}
      _K_configmap=""
      return 1
    fi
  fi
}

function _printUsage_kdp(){
  echo "Command kdp:"
  echo "Usage: kdp pod [-n namespace]"
  echo "Describe pod"
  echo "A.K.A. kubectl describe pod"
}
function kdp(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    _printUsage_kdp
    return 1
  fi
  pod=${opts[0]}
  opts[0]=""
  _setup_opts_pod_namespace $pod

  if [[ ! -z ${_K_pod} ]];then
    ns=`_getNamespaceOPT`
    echo "EXEC COMMAND: kubectl describe pod $pod ${ns} ${opts[@]}"
    kubectl describe pod $pod ${ns} ${opts[@]}
  fi
}

function _printUsage_kl(){
  echo "Command kl:"
  echo "Usage: kl pod [-n namespace]"
  echo "Display pod log"
  echo "A.K.A. kubectl logs"
}

function kl(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    echo "Usage: kl pod [-n namespace] [-c container]"
    return 1
  fi
  pod=${opts[0]}
  opts[0]=""
  _setup_opts_pod_namespace $pod
  _setup_opts_container ${_K_pod} ${_K_namespace}

  if [[ ! -z ${_K_pod} && ! -z ${_K_container} ]];then
    ns=`_getNamespaceOPT`
    cont=`_getContainerOPT`
    echo "EXEC COMMAND: kubectl logs  ${_K_pod} ${ns} ${cont} ${opts[@]}"
    kubectl logs  ${_K_pod} ${ns} ${cont} ${opts[@]}
  fi
}

function _printUsage_klf(){
  echo "Command klf:"
  echo "Usage: klf pod [-n namespace]"
  echo "Continuesly get pod log"
  echo "A.K.A kubectl logs -f"

}
function klf(){
  kl $@ -f
}

function _printUsage_ke(){
  echo "Command ke:"
  echo "Usage: ke pod [-n namespace] [-c container] [command]"
  echo "Run kubectl exec against a container.  command is default to -it bash"
  echo "A.K.A kubectl exec"
}

function ke(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    echo "Usage: ke pod [-n namespace] [-c container] command"
    return 1
  fi
  pod=${opts[0]}
  if [[ ! -z ${opts[1]} ]];then
    opts[0]=""
    command=${opts[@]}
  else
    command=' -it bash'
  fi
  _setup_opts_pod_namespace $pod
  _setup_opts_container ${_K_pod} ${_K_namespace}

  if [[ ! -z ${_K_pod} && ! -z ${_K_container} ]];then
    ns=`_getNamespaceOPT`
    cont=`_getContainerOPT`
    kubectl exec ${_K_pod} ${ns} ${cont} ${command}
    echo "EXEC COMMAND: kubectl exec  ${_K_pod} ${ns} ${cont} ${command}"
  fi
}

function _printUsage_kgc(){
  echo "Command kgc:"
  echo "Usage: kgc configmap [-n namespace] [options]"
  echo "Get configmap to display as yaml by default"
  echo "A.K.A kubectl get configmap"
}

function kgc(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    _printUsage_kgc
    return 1
  fi
  configmap=${opts[0]}
  if [[ ! -z ${opts[1]} ]];then
    options=${opts[1]}
  else
    options=" -o yaml"
  fi

  _setup_opts_configmap $configmap

  if [[ ! -z ${_K_configmap} ]];then
    ns=`_getNamespaceOPT`
    echo "EXEC COMMAND: kubectl get configmaps  $_K_configmap ${ns} ${options}"
    kubectl get configmaps  $_K_configmap ${ns} ${options}
  fi
}

function _printUsage_kgotoyamls(){
  echo "Command kgotoyamls:"
  echo "Usage: kgotoyamls service [output_folder_in_NFS]"
  echo "Goto yamls folder of a service, by default, output_folder_in_NFS is set to /var/vols/itom/core/suite-install/itsma/output"
}
function kgotoyamls(){
  if [[ $# -lt 1 ]];then
    _printUsage_kgotoyamls
    return 1
  fi
  _setup_opts_serviceName $@
  if [[ -z ${_K_servicename} ]];then
    _printUsage_kgotoyamls
    return 1
  fi

  if [[ ! -z $2 ]];then
    ybpath=$2
  else
    pybpathath=""
  fi

  path=`_getYamlsPath ${_K_servicename} ${ybpath}`
  echo "EXEC COMMAND: cd $path"
  cd $path

}

function _printUsage_kgotolog(){
  echo "Command kgotolog:"
  echo "Usage: kgotolog pod [-n namespace] [log_folder_in_NFS]"
  echo "Goto log folder of a pod, by default logs are in /var/vols/itom/itsma"
}

function kgotolog(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    _printUsage_kgotolog
    return 1
  fi
  pod=${opts[0]}

  if [[ ! -z ${opts[1]} ]];then
    logbasepath=${opts[1]}
  else
    logbasepath=""
  fi

  _setup_opts_pod_namespace $pod
  if [[ ! -z ${_K_pod} ]];then
    path=`_getPodLogPath ${_K_pod} ${logbasepath}`
    if [[ $path = '' ]];then
        echo "The log folder doesnot exist for ${_K_pod}"
    else
        echo "EXEC COMMAND: cd $path"
        cd $path
    fi
  fi
}

function _printUsage_wkgp(){
  echo "Command wkgp:"
  echo "Usage: wkgp [pod] [-n namespace]"
  echo "watch status change of all pods or matched pods"
  echo "A.K.A  watch "kubectl get pod" "
}

function wkgp(){
    command=`_generateGetPodCommand $@`
    wcommand="watch \"$command\""
    echo "EXECUTE CMD: $wcommand"
    eval $wcommand
}

function _printUsage_kgp(){
  echo "Command kgp:"
  echo "Usage: kgp [pod] [-n namespace]"
  echo "Get all pods or matched pods"
  echo "A.K.A kubectl get pods"
}

function kgp(){
    command=`_generateGetPodCommand $@`
    echo "EXECUTE CMD: $command"
    eval $command
}

function _printUsage_kec(){
  echo "Command kec:"
  echo "Usage: kec configmap [-n namespace]"
  echo "edit configmap"
  echo "A.K.A kubectl edit configmap"
}

function kec(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 1 ]];then
    _printUsage_kec
    return 0
  fi
  configmap=${opts[0]}

  _setup_opts_configmap $configmap

  if [[ ! -z ${_K_configmap} ]];then
    ns=`_getNamespaceOPT`
    echo "EXEC COMMAND: kubectl edit configmap  $configmap ${ns}"
    kubectl edit configmap  $configmap ${ns}
  fi
  }

function _printUsage_krestart(){
  echo "Command krestart:"
  echo "Usage: krestart yamlfile/yamlfolder"
  echo "Stop yaml specified and restart it"
  echo "A.K.A kubectl delete -f && kubectl create -f"
}

function krestart(){
  kubectl delete -f $1 && kubectl create -f $1
}

function _printUsage_kcopyout(){
  echo "Command kcopyout:"
  echo "Usage: kcopyout pod sourceFile [destFile] [-n namespace] [-c container]"
  echo "Copy sourceFile in container specified out to sourceFile"
  echo "A.K.A kubectl cp"
}

function kcopyout(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 2 ]];then
    _printUsage_kcopyout
    return 0
  fi
  pod=${opts[0]}
  source=${opts[1]}
  source=${source%%/}
  if [[ ! -z ${opts[2]} ]];then
    dest="${opts[2]}"
  else
    dest="./${source##*/}"
  fi

  _setup_opts_pod_namespace $pod
  _setup_opts_container ${_K_pod} ${_K_namespace}

  if [[ -z ${_K_pod} || -z ${_K_container} ]];then
    echo "Didn't get pod and container"
    return 1
  fi
  ns=`_getNamespaceOPT`
  cont=`_getContainerOPT`
  echo "EXEC COMMAND: kubectl cp ${ns} ${cont} ${_K_pod}:${source} ${dest}"
  kubectl cp ${ns} ${cont} ${_K_pod}:${source} ${dest}
}

function _printUsage_kcopyinto(){
  echo "Command kcopyinto:"
  echo "Usage: kcopyout pod sourceFile [destFile] [-n namespace] [-c container]"
  echo "Copy sourceFile into destFile in container specified"
  echo "A.K.A kubectl cp"
}

function kcopyinto(){
  _setup_opts_args $@
  IFS=' ' read -r -a opts <<< ${_K_args}
  if [[ ${#opts[@]} -lt 2 ]];then
    _printUsage_kcopyinto
    return 1
  fi
  pod=${opts[0]}
  source=${opts[1]}
  source=${source%%/}
  if [[ ! -z ${opts[2]} ]];then
    dest="${opts[2]}"
  else
    dest="~/${source##*/}"
  fi

  _setup_opts_pod_namespace $pod
  _setup_opts_container ${_K_pod} ${_K_namespace}

  if [[ -z ${_K_pod} || -z ${_K_container} ]];then
    return 1
  fi
    ns=`_getNamespaceOPT`
    cont=`_getContainerOPT`
    echo "EXEC COMMAND: kubectl cp ${ns} ${cont} ${source} ${_K_pod}:${dest}"
    kubectl cp ${ns} ${cont} ${source} ${_K_pod}:${dest}
}


function _printUsage_kgetimages(){
  echo "Command kgetimages:"
  echo "Usage: kgetimages"
  echo "Get all images except vault"

}

function kgetimages(){

    for i in `kubectl get deployment --all-namespaces | awk 'NR>1{print $1":"$2}'`;do
        echo "${i}:$(kubectl get deployment  ${i##*:} -n ${i%%:*} -o jsonpath='{range ..containers[?(@.name!="kubernetes-vault-renew")]}{.image}{"\n"}{end}')"
    done

}
function kaliasHelp(){

  echo "####kaliasHelp####"
  _printUsage_kgn
  _printUsage_kgp
  _printUsage_kgcs
  _printUsage_kgc
  _printUsage_kl
  _printUsage_klf
  _printUsage_kcreate
  _printUsage_kdelete
  _printUsage_krestart
  _printUsage_kcopyout
  _printUsage_kcopyinto
  _printUsage_ke
  _printUsage_kec
  _printUsage_kgotolog
  _printUsage_kgotoyamls
  _printUsage_kgetimages
}
