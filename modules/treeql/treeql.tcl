# treeql.tcl
# A generic tree query language in snit
#
# Copyright 2004 Colin McCormack.
# You are permitted to use this code under the same license as tcl.
#
# 20040930 Colin McCormack - initial release to tcllib

package provide treeql 1.1

package require Tcl 8.5
package require snit
package require struct::list
package require struct::set

proc K {x y} {
    set x
}

snit::type treeql {
    variable nodes	;# set of all nodes
    variable tree	;# tree over which nodes are defined
    variable query	;# full query - ie: 'parent' of this treeql object

    # low level accessor to tree
    method treeObj {} {
	return $tree
    }

    # apply the [$tree cmd {expand}$args] form to each node
    # returns the list of results of application
    method apply {cmd args} {

	set result {}
	foreach node $nodes {
	    set application [$tree {expand}$cmd $node {expand}$args] 
	    #puts stderr "Apply: $tree $cmd $node $args -> $application"
	    if {[catch {lappend result {expand}$application} x eo]} {
		puts stderr "Apply ERROR: $tree $cmd $node $args -> $application - $eo"
	    }
	}

	return $result
    }

    # apply the [$tree cmd {expand}$args] form to each node
    # returns the concatenated strings of results of application
    method sapply {cmd args} {

	set result {}
	foreach node $nodes {
	    set application [$tree {expand}$cmd $node {expand}$args] 
	    #puts stderr "Sapply: $tree $cmd $node $args -> $application"
	    append result $application " "
	}

	return $result
    }

    # filter nodes by [$tree cmd {expand}$args]
    # returns the list of results of application when application is non nil
    method filter {cmd args} {

	set result {}
	foreach node $nodes {
	    set application [$tree {expand}$cmd $node {expand}$args]
	    #puts stderr "Filter: $tree $cmd $node $args -> $application"
	    if {$application != {}} {
		lappend result $application
	    }
	}

	return $result
    }

    # filter nodes by the predicate [$tree cmd {expand}$args]
    # returns the list of results of application when application is true
    method bool {cmd args} {

	#puts stderr "Bool: $tree $cmd - $args"
	#set result [::struct::list filter $nodes [list $tree $cmd {expand}$args]]
	#puts stderr "Bool: $tree $cmd - $nodes - $args -> $result"
	#return $result

	# replaced by tcllib's list filter
	set result {}
	foreach node $nodes {
	    set application [$tree {expand}$cmd $node {expand}$args]
	    #puts stderr "Bool: $tree $cmd $node $args -> $application - [$tree dump $node]"
	    if {$application} {
		lappend result $node
	    }
	}

	return $result
    }

    # applyself - map cmd on $self to each node, discarding null results
    method applyself {cmd args} {

	set result {}
	foreach node $nodes {
	    set application [$query {expand}$cmd $node {expand}$args] 
	    if {[llength $application]} {
		lappend result {expand}$application
	    }
	}

	return $result
    }

    # mapself - map cmd on $self to each node
    method mapself {cmd args} {

	set result {}
	foreach node $nodes {
	    set application [$query {expand}$cmd $node {expand}$args] 
	    #puts stderr "Mapself: $query $cmd $node $args -> $application"
	    lappend result $application
	}

	return $result
    }

    # shim to perform operation $op on attribute $attr of $node
    method do_attr {node op attr} {
	set attrv [$tree get $node $attr]
	#puts stderr "$self do_attr node:'$node' op:'$op' attr:'$attr' attrv:'$attrv'"
	return [{expand}$op $attrv]
    }

    # filter nodes by predicate [string $op] over attribute $attr
    method stringP {op attr args} {
	set n {}
	foreach result [$self mapself do_attr [list string {expand}$op] $attr] node $nodes {
	    #puts stderr "$self stringP $op $attr -> $result - $node"
	    if {$result} {
		lappend n $node
	    }
	}
	set nodes $n
	return $args
    }

    # filter nodes by negated predicate [string $op] over attribute $attr
    method stringNP {op attr args} {
	set n {}
	foreach result [$self mapself do_attr [list string {expand}$op] $attr] node $nodes {
	    if {!$result} {
		lappend n $node
	    }
	}
	set nodes $n
	return $args
    }

    # filter nodes by predicate [expr {expand}$op] over attribute $attr
    method exprP {op attr args} {
	set n {}
	foreach result [$self mapself do_attr [list expr {expand}$op] $attr] node $nodes {
	    if {$result} {
		lappend n $node
	    }
	}
	set nodes $n
	return $args
    }

    # filter nodes by predicate ![expr {expand}$op] over attribute $attr
    method exprNP {op attr args} {
	set n {}
	foreach result [$self mapself do_attr [list expr {expand}$op] $attr] node $nodes {
	    if {!$result} {
		lappend n $node
	    }
	}
	set nodes $n
	return $args
    }

    # shim to return string values of attributes matching $pattern of a given $node
    method do_getvals {node pattern} {
	set result {}
	foreach key [$tree keys $node $pattern] {
	    lappend result [list [$tree get $node $key]]
	}
	return $result
    }

    # Return list of attribute values of attributes matching $pattern
    method getvals {pattern args} {
	set nodes [$self mapself do_getvals $pattern]
	return $args	;# this terminates a query
    }

    # Returns list of attribute values of attributes matching $attr - 
    method get {attr args} {
	return [$self getvals $attr {expand}$args]
    }

    # Returns list of attribute values of the current node, in an unspecified order.
    method attlist {args} {
	return [$self getvals * {expand}$args]
    }

    # Returns list of lists of attributes of each node
    method attrs {glob args} {
	set nodes [$self apply keys $glob]
	return $args
    }

    # shim to find node ancestors by repetitive [parent]
    # as tcllib tree lacks this
    method do_ancestors {node} {
	set ancestors {}
	set rootname [$tree rootname]
	while {$node ne $rootname} {
	    lappend ancestors $node
	    set node [$tree parent $node]
	}
	lappend ancestors $rootname
	return $ancestors
    }

    # path from node to root
    method ancestors {args} {
	set nodes [$self applyself do_ancestors]
	return $args 
   }

    # shim to find $node rootpath by repetitive [parent]
    # as tcllib tree lacks this
    method do_rootpath {node} {
	set ancestors {}
	set rootname [$tree rootname]
	while {$node ne $rootname} {
	    lappend ancestors $node
	    set node [$tree parent $node]
	}
	lappend ancestors $rootname
	return [::struct::list reverse $ancestors]
    }

    # path from root to node
    method rootpath {args} {
	set nodes [$self applyself do_rootpath]
	return $args
    }

    # node parent
    method parent {args} {
	set nodes [$self apply parent]
	return $args
    }

    # node children
    method children {args} {
	set nodes [$self apply children]
	return $args
    }

    # previous sibling
    method left {args} {
	set nodes [$self apply previous]
	return $args
    }

    # next sibling
    method right {args} {
	set nodes [$self apply next]
	return $args
    }

    # shim to find left siblings of node, in order of occurrence
    method do_previous* {node} {
	if {$node == [$tree rootname]} {
	    set children $node
	} else {
	    set children [$tree children [$tree parent $node]]
	}
	set index [expr {[lsearch $children $node] - 1}]
	return [lrange $children 0 $index]
    }

    # previous siblings in reverse order
    method prev {args} {
	set nodes [::struct::list reverse [$self applyself do_previous*]]
	return $args
    }

    # previous siblings in tree order
    method esib {args} {
	set nodes [$self applyself do_previous*]
	return $args
    }

    # shim to find next siblings in tree order
    method do_next* {node} {
	if {$node == [$tree rootname]} {
	    set children $node
	} else {
	    set children [$tree children [$tree parent $node]]
	}
	set index [expr {[lsearch $children $node] + 1}]
	return [lrange $children $index end]
    }

    # next siblings in tree order
    method next {args} {
	set nodes [$self applyself do_next*]
	return $args
    }

    # generates the tree root
    method root {args} {
	set nodes [$tree rootname]
	return $args
    }

    # generates the tree root
    method rootname {args} {
	set nodes [$tree rootname]
	return $args
    }

    # shim to calculate descendants
    method do_subtree {node} {
	set nodeset $node
	set children [$tree children $node]
	foreach child $children {
	    set descendants [$self do_subtree $child]
	    lappend nodeset {expand}$descendants
	}
	#puts stderr "do_subtree $node -> $nodeset"
	return $nodeset
    }

    # generates proper-descendants of nodes
    method descendants {args} {
	set desc {}
	set nodeset {}
	foreach node $nodes {
	    set subtree [$self do_subtree $node]
	    set descendants [lrange $subtree 1 end]
	    lappend nodeset {expand}$descendants
	}
	set nodes $nodeset
	return $args
    }

    # generates all subtrees rooted at node
    method subtree {args} {
	set nodeset {}
	foreach node $nodes {
	    set descendants [$self do_subtree $node]
	    lappend nodeset {expand}$descendants
	}
	set nodes $nodeset
	return $args
    }

    # generates all nodes in the tree
    method tree {args} {
	set nodes [$self do_subtree [$tree rootname]]
	return $args
    }

    # generates all subtrees rooted at node
    #method descendants {args} {
    #	set nodes [$tree apply descendants]
    #	return $args
    #}

    # flattened next subtrees
    method forward {args} {
	set nodes [$self applyself do_next*]	;# next siblings
	$self descendants	;# their subtrees
	return $args
    }

    # synonym for [forward]
    method later {args} {
	$self forward
	return $args
    }

    # flattened previous subtrees in tree order
    method earlier {args} {
	set nodes [$self applyself do_previous*]	;# all earlier siblings
	$self subtree	;# their subtrees
	return $args
    }

    # flattened previous subtrees in reverse tree order
    # FIXME - this isn't going to return things in the correct order
    method backward {args} {
	set nodes [$self applyself do_previous*]	;# all earlier siblings
	$self subtree	;# their subtrees
	set nodes [::struct::list reverse $nodes]	;# reverse order
	return $args
    }

    # Returns the node type of nodes
    method nodetype {args} {
	set nodes [$self sapply get @type]
	return $args
    }

    # Reduce to nodes of @type $t
    method oftype {t args} {
	return [$self stringP [list equal -nocase $t] @type {expand}$args]
    }

    # Reduce to nodes not of @type $t
    method nottype {t args} {
	return [$self stringNP [list equal -nocase $t] @type {expand}$args]
    }

    # Reduce to nodes whose @type is one of $attrs
    # @type values are assumed to be simple strings
    method oftypes {attrs args} {
	set n {}
	foreach result [$self mapself do_attr list @type] node $nodes {
	    if {[lsearch $attrs $result] > -1} {
		#puts stderr "$self oftypes '$attrs' -> $result - $node"
		lappend n $node
	    }
	}
	set nodes $n
	return $args
    }

    # Reduce to nodes with attribute $attr (can be a glob)
    method hasatt {attr args} {
	set nodes [$self bool keyexists $attr]
	return $args
    }

    # Returns values of attribute attname
    method attval {attname args} {
	$self hasatt $attname	;# only nodes with attribute
	set nodes [$self sapply get $attname]	;# get the attribute nodes
	return $args
    }

    # Reduce to nodes with attribute $attr of $value
    method withatt {attr value args} {
	$self hasatt $attr	;# only nodes with attribute
	return [$self stringP [list equal -nocase $value] $attr {expand}$args]
    }

    # Reduce to nodes with attribute $attr of $value
    method withatt! {attr val args} {
	return [$self stringP [list equal $val] $attr {expand}$args]
    }

    # Reduce to nodes with attribute $attr value one of $vals
    method attof {attr vals args} {

	set result {}
	foreach node $nodes {
	    set x [string tolower [[$self treeObj] get $node $attr]]
	    if {[lsearch $vals $x] != -1} {
		lappend result $node
	    }
	}

	set nodes $result
	return $args
    }

    # Reduce to nodes whose attribute $attr string matches $match
    method attmatch {attr match args} {
	$self stringP [list match {expand}$match] $attr
	return $args
    }

    # Side Effect: set attribute $attr to $val
    method set {attr val args} {
	$self apply set $attr $val
	return $args
    }

    # Side Effect: unset attribute $attr
    method unset {attr args} {
	$self apply unset $attr
	return $args
    }

    # apply string operation $op to attribute $attr on each node
    method string {op attr args} {
	set nodes [$self mapself do_attr [list string {expand}$op] $attr]
	return $args
    }

    # remove duplicate nodes, preserving order
    method unique {args} {
	set all {}
	array set keys {}
	foreach node $nodes {
	    if {![info exists keys($node)]} {
		set keys($node) 1
		lappend all $node
	    }
	}
	set nodes $all
	return $args
    }

    # construct the set of nodes present in both $nodes and node set $and
    method and {and args} {
	set nodes [::struct::set intersect $and $nodes]
	return $args
    }

    # return result of new query $query, preserving current node set
    method subquery {args} {
	set org $nodes	;# save current node set
	set new [$query query {expand}$args]
	set nodes $org	;# restore old node set

	return $new
    }

    # perform a subquery and and in the result
    method andq {q args} {
	$self and [$self subquery {expand}$q]
	return $args
    }

    # construct the set of nodes present in $nodes or node set $or
    method or {or args} {
	set nodes [::struct::set union $nodes $or]
	$self unique
	return $args
    }

    # perform a subquery and or in the result
    method orq {q args} {
	$self or [$self subquery {expand}$q] 
	return $args
    }

    # construct the set of nodes present in $nodes but not node set $not
    method not {not args} {
	set nodes [::struct::set difference $nodes $not]
	return $args
    }

    # perform a subquery and return the set of nodes not in the result
    method notq {q args} {
	$self not [$self subquery {expand}$q] 
	return $args
    }

    # select the first of the nodes
    method select {args} {
	set nodes [lindex $nodes 0]
	return $args
    }

    # perform a subquery then replace the nodeset
    method transform {var query body args} {
	set new {}
	foreach n [$self subquery {expand}$query] {
	    uplevel 1 set $var $n
	    switch [catch {uplevel 1 $body} result eo] {
		ok {
		    lappend new $result
		}
		error {
		    error $result
		}
		return {
		    set nodes $result
		    return
		}
		break {
		    break;
		}
		continue {
		    continue;
		}
	    }
	}

	set nodes $new

	return $args
    }

    # perform a subquery $query then map $body over results
    method foreach {var q body args} {
	foreach n [$self subquery {expand}$q] {
	    uplevel 1 set $var $n
	    uplevel 1 $body
	}
	return $args
    }
    
    # perform a query, then evaluate $body
    method with {q body args} {

	# save current node set
	set org $nodes; set nodes {}

	$self query {expand}$q
	set result [uplevel 1 $body]

	# restore old node set
	set new $nodes; set nodes $org

	return $args
    }

    # map $body over $nodes
    method over {var body args} {

	set result {}
	foreach n $nodes {
	    uplevel 1 set $var $n
	    uplevel 1 $body
	}
	return $args
    }

    # perform the query
    method query {args} {

	# iterate over the args, treating each as a method invocation
	while {$args != {}} {
	    #puts stderr "query $self $args"
	    set args [$query {expand}$args]
	    #puts stderr "-> $nodes"
	}

	return $nodes
    }

    # append the literal $val to node set
    method quote {val args} {
	lappend nodes $val
	return $args
    }

    # replace the node set with the literal
    method replace {val args} {
	set nodes $val
	return $args
    }

    # set nodeset to empty
    method reset {args} {
	set nodes {}
	return $args
    }

    # delete all nodes in node set
    method delete {args} {

	foreach node $nodes {
	    $tree cut $node
	}

	set nodes {}
	return $args
    }

    # return the node set
    method result {} {
	return $nodes
    }

    constructor {args} {
	set query [from args -query ""]
	if {$query == ""} {
	    set query $self
	}

	set nodes [from args -nodes {}]

	set tree [from args -tree ""]

	$self query {expand}$args
    }

    # Return result, and destroy this query
    # useful in constructing a sub-query
    method discard {args} {
	return [K [$self result] [$self destroy]]
    }
}
