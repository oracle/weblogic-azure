# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

all:
	cp subtemplate-src/addnode-coherence.md cluster/addnode-coherence.md
	cp subtemplate-src/addnode-coherence.md dynamic-cluster/addnode-coherence.md
	cp subtemplate-src/admin-aadNestedTemplate.md admin/aadNestedTemplate.md
	cp subtemplate-src/admin-customDNSTemplate.md admin/customDNSTemplate.md
	cp subtemplate-src/admin-elkNestedTemplate.md admin/elkNestedTemplate.md
	cp subtemplate-src/appGatewayNestedTemplate.md cluster
	cp subtemplate-src/cluster-aadNestedTemplate.md cluster/aadNestedTemplate.md
	cp subtemplate-src/cluster-addnode.md cluster/addnode.md
	cp subtemplate-src/cluster-customDNSTemplate.md cluster/customDNSTemplate.md
	cp subtemplate-src/cluster-deletenode.md cluster/deletenode.md
	cp subtemplate-src/cluster-elkNestedTemplate.md cluster/elkNestedTemplate.md
	cp subtemplate-src/cluster-nsgRulesTemplate.md cluster/nsgRulesTemplate.md
	cp subtemplate-src/coherenceTemplate.md cluster/coherenceTemplate.md
	cp subtemplate-src/coherenceTemplate.md dynamic-cluster/coherenceTemplate.md
	cp subtemplate-src/dbTemplate.md admin
	cp subtemplate-src/dbTemplate.md cluster
	cp subtemplate-src/dbTemplate.md dynamic-cluster
	cp subtemplate-src/dynamic-cluster-aadNestedTemplate.md dynamic-cluster/aadNestedTemplate.md
	cp subtemplate-src/dynamic-cluster-addnode.md dynamic-cluster/addnode.md
	cp subtemplate-src/dynamic-cluster-deletenode.md dynamic-cluster/deletenode.md
	cp subtemplate-src/dynamic-cluster-elkNestedTemplate.md dynamic-cluster/elkNestedTemplate.md
	cp subtemplate-src/dynamic-cluster-nsgRulesTemplate.md dynamic-cluster/nsgRulesTemplate.md
	cp subtemplate-src/dynamic-cluster-ohsNestedTemplate.md dynamic-cluster/ohsNestedTemplate.md
	cp subtemplate-src/dynamic-cluster-customDNSTemplate.md dynamic-cluster/customDNSTemplate.md
