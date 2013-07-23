
graph = {}

torch.include('graph','utils.lua')
torch.include('graph','Node.lua')
torch.include('graph','Edge.lua')


--[[
	Defines a graph and general operations on grpahs like topsort, 
	connected components, ...
	uses two tables, one for nodes, one for edges
]]--
local Graph = torch.class('graph.Graph')

function Graph:__init()
	self.nodes = {}
	self.edges = {}
end

-- add a new edge into the graph.
-- an edge has two fields, from and to that are inserted into the
-- nodes table. the edge itself is inserted into the edges table.
function Graph:add(edge)
	if type(edge) ~= 'table' then
		error('graph.Edge or {graph.Edges} expected')
	end
	if torch.typename(edge) then
		-- add edge
		if not self.edges[edge] then
			table.insert(self.edges,edge)
			self.edges[edge] = #self.edges
		end
		-- add from node
		if not self.nodes[edge.from] then
			table.insert(self.nodes,edge.from)
			self.nodes[edge.from] = #self.nodes
		end
		-- add to node
		if not self.nodes[edge.to] then
			table.insert(self.nodes,edge.to)
			self.nodes[edge.to] = #self.nodes
		end
		-- add the edge to the node for parsing in nodes
		edge.from:add(edge.to)
		edge.from.id = self.nodes[edge.from]
		edge.to.id = self.nodes[edge.to]
	else
		for i,e in ipairs(edge) do
			self:add(e)
		end
	end
end

-- Clone a Graph
-- this will create new nodes, but will share the data.
-- Note that primitive data types like numbers can not be shared
function Graph:clone()
	local clone = graph.Graph()
	local nodes = {}
	for i,n in ipairs(self.nodes) do
		table.insert(nodes,n.new(n.data))
	end
	for i,e in ipairs(self.edges) do
		local from = nodes[self.nodes[e.from]]
		local to   = nodes[self.nodes[e.to]]
		clone:add(e.new(from,to))
	end
	return clone
end

-- It returns a new graph where the edges are reversed.
-- The nodes share the data. Note that primitive data types can
-- not be shared.
function Graph:reverse()
	local rg = graph.Graph()
	local mapnodes = {}
	for i,e in ipairs(self.edges) do
		mapnodes[e.from] = mapnodes[e.from] or e.from.new(e.from.data)
		mapnodes[e.to]   = mapnodes[e.to] or e.to.new(e.to.data)
		local from = mapnodes[e.from]
		local to   = mapnodes[e.to]
		rg:add(e.new(to,from))
	end
	return rg,mapnodes
end

--[[
	Topological Sort
	** This is not finished. OK for graphs with single root.
]]--
function Graph:topsort()

	-- reverse the graph
	local rg,map = self:reverse()
	local rmap = {}
	for k,v in pairs(map) do
		rmap[v] = k
	end

	-- work on the sorted graph
	local sortednodes = {}
	local rootnodes = rg:roots()

	if #rootnodes == 0 then
		error('Graph has cycles')
	end

	-- run
	for i,root in ipairs(rootnodes) do
		root:dfs(function(node) table.insert(sortednodes,rmap[node]) end)
	end

	if #sortednodes ~= #self.nodes then
		error('Graph has cycles')
	end
	return sortednodes,rg,rootnodes
end

-- find root nodes
function Graph:roots()
	local edges = self.edges
	local rootnodes = {}
	for i,edge in ipairs(edges) do
		--table.insert(rootnodes,edge.from)
		if not rootnodes[edge.from] then
			rootnodes[edge.from] = #rootnodes+1
		end
	end
	for i,edge in ipairs(edges) do
		if rootnodes[edge.to] then
			rootnodes[edge.to] = nil
		end
	end
	local roots = {}
	for root,i in pairs(rootnodes) do
		table.insert(roots, root)
	end
	table.sort(roots,function(a,b) return self.nodes[a] < self.nodes[b] end )
	return roots
end

-- find root nodes
function Graph:leaves()
	local edges = self.edges
	local leafnodes = {}
	for i,edge in ipairs(edges) do
		--table.insert(rootnodes,edge.from)
		if not leafnodes[edge.to] then
			leafnodes[edge.to] = #leafnodes+1
		end
	end
	for i,edge in ipairs(edges) do
		if leafnodes[edge.from] then
			leafnodes[edge.from] = nil
		end
	end
	local leaves = {}
	for leaf,i in pairs(leafnodes) do
		table.insert(leaves, leaf)
	end
	table.sort(leaves,function(a,b) return self.nodes[a] < self.nodes[b] end )
	return leaves
end

function Graph:todot(title)
	local nodes = self.nodes
	local edges = self.edges
	local str = {}
	table.insert(str,'digraph G {\n')
	if title then
		table.insert(str,'labelloc="t";\nlabel="' .. title .. '";\n')
	end
	table.insert(str,'node [shape = oval]; ')
	local nodelabels = {}
	for i,node in ipairs(nodes) do
		local l =  '"' .. ( 'Node' .. node.id .. '\\n' .. node:label() ) .. '"'
		nodelabels[node] = 'n' .. node.id
		table.insert(str, '\n' .. nodelabels[node] .. '[label=' .. l .. '];')
	end
	table.insert(str,'\n')
	for i,edge in ipairs(edges) do
		table.insert(str,nodelabels[edge.from] .. ' -> ' .. nodelabels[edge.to] .. ';\n')
	end
	table.insert(str,'}')
	return table.concat(str,'')
end

