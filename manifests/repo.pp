# = Define a git repository as a resource
#
# == Parameters:
#
# $source::			The URI to the source of the repository
#
# $path::				The path where the repository should be cloned to, fully qualified paths are recommended, and the $owner needs write permissions.
# 
# $checkout::		The branch or tag to be checked out
#
# $owner::			The user who should own the repository
# 
# $update::			If this is true, puppet will pull any changes when it runs.
#
# $bare::				If this is true, git will create a bare repository

define git::repo(
	$path,
	$source		= false,
	$branch		= 'master',
	$tag 			= false,
	$owner		= 'root',
	$update		= false,
	$bare			= false
){
	
	require git
	require git::params

	if $source {
		$init_cmd = "${git::params::bin} clone -b ${branch} ${source} ${path} --recursive"
	} else {
		if $bare {
			$init_cmd = "${git::params::bin} init --bare ${target}"
    } else {
      $init_cmd = "${git::params::bin} init ${target}"
    }
	}

	$creates = $bare ? {
		true		=> "${path}/objects",
		default	=> "${path}/.git",
	}

	exec {"git_repo_${name}":
		user 		=> root,
		command	=> $init_cmd,
		creates	=> $creates,
		require => Package[$git::params::package],
		notify	=> File[$path],
		timeout => 600,
	}

	file{$path:
		ensure 	=> directory,
		owner		=> $owner,
		recurse => true,
	}

	# I think tagging works, but it's possible setting a tag and a branch will just fight.
	# It should change branches too...

	if $tag {
		exec {"git_${name}_co_tag":
			user 		=> $owner,
			cwd			=> $path,
			command => "${git::params::bin} checkout ${tag}",
			unless	=> "${git::params::bin} describe --tag|/bin/grep -P '^${tag}$'",
			require => Exec["git_repo_${name}"],
		}
	} else {
		exec {"git_${name}_co_branch":
			user 		=> $owner,
			cwd			=> $path,
			command => "${git::params::bin} checkout ${branch}",
			unless	=> "${git::params::bin} branch|/bin/grep -P '^\\* ${branch}$'",
			require => Exec["git_repo_${name}"],
		}
		if $update {
			exec {"git_${name}_pull":
				user 		=> $owner,
				cwd			=> $path,
				command => "${git::params::bin} pull origin ${branch}",
				unless	=> "${git::params::bin} diff origin ${branch} --exit-code --no-color",
				require => Exec["git_repo_${name}"],
			}
		}
	}

}