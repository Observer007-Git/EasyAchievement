local _, Addon = ...

local TreeLayout = {}
Addon.AchievementTreeLayout = TreeLayout

function TreeLayout.Calculate(nodes, edges, root, options)
    local availableHeight = options.availableHeight
    local branchGap = options.branchGap
    local levelGap = options.levelGap
    local nodeRowPitch = options.nodeRowPitch

    local childrenByID = {}
    local primaryParent = {}
    for _, node in ipairs(nodes) do
        childrenByID[node.id] = {}
    end
    for _, edge in ipairs(edges) do
        if not primaryParent[edge.child.id] then
            primaryParent[edge.child.id] = edge.parent.id
            childrenByID[edge.parent.id][
                #childrenByID[edge.parent.id] + 1] = edge.child
        end
    end

    local wrappedLayouts = {}
    local function PackSubtrees(items)
        local lanes = {}
        for _, item in ipairs(items) do
            local itemLayout = wrappedLayouts[item.id]
            local itemHeight = itemLayout.height
            local lane
            local bestRemaining
            for _, candidate in ipairs(lanes) do
                local nextHeight = candidate.height + branchGap + itemHeight
                if nextHeight <= availableHeight then
                    local remaining = availableHeight - nextHeight
                    if not bestRemaining or remaining < bestRemaining then
                        lane = candidate
                        bestRemaining = remaining
                    end
                end
            end
            if not lane then
                lane = { items = {}, height = 0, width = 0 }
                lanes[#lanes + 1] = lane
            end
            if lane.height > 0 then
                lane.height = lane.height + branchGap
            end
            lane.items[#lane.items + 1] = item
            lane.height = lane.height + itemHeight
            lane.width = math.max(lane.width, itemLayout.width)
        end
        local height = nodeRowPitch
        local width = 0
        for _, packedLane in ipairs(lanes) do
            height = math.max(height, packedLane.height)
            packedLane.offset = width
            width = width + packedLane.width + levelGap
        end
        if width > 0 then
            width = width - levelGap
        end
        return lanes, height, width
    end

    local function BuildWrappedLayout(node)
        if wrappedLayouts[node.id] then
            return wrappedLayouts[node.id]
        end
        local children = childrenByID[node.id]
        if #children == 0 then
            wrappedLayouts[node.id] = {
                height = nodeRowPitch,
                width = node.layoutWidth,
            }
            return wrappedLayouts[node.id]
        end
        for _, child in ipairs(children) do
            BuildWrappedLayout(child)
        end
        local lanes, height, childrenWidth = PackSubtrees(children)
        local childrenOffset = node.layoutWidth + levelGap
        wrappedLayouts[node.id] = {
            lanes = lanes,
            height = height,
            width = math.max(node.layoutWidth,
                childrenOffset + childrenWidth),
        }
        return wrappedLayouts[node.id]
    end

    local roots = { root }
    for _, node in ipairs(nodes) do
        if node ~= root and not primaryParent[node.id] then
            roots[#roots + 1] = node
        end
    end
    for _, treeRoot in ipairs(roots) do
        BuildWrappedLayout(treeRoot)
    end
    local rootLanes, treeHeight = PackSubtrees(roots)

    local verticalPositions = {}
    local horizontalPositions = {}
    local function PositionSubtree(node, top, left)
        local layout = wrappedLayouts[node.id]
        horizontalPositions[node.id] = left
        if not layout.lanes then
            verticalPositions[node.id] = top + layout.height / 2
            return
        end

        local childrenLeft = left + node.layoutWidth + levelGap
        for _, lane in ipairs(layout.lanes) do
            local childTop = top + (layout.height - lane.height) / 2
            local laneLeft = childrenLeft + lane.offset
            for _, child in ipairs(lane.items) do
                PositionSubtree(child, childTop, laneLeft)
                childTop = childTop + wrappedLayouts[child.id].height
                    + branchGap
            end
        end
        verticalPositions[node.id] = top + layout.height / 2
    end

    for _, lane in ipairs(rootLanes) do
        local rootTop = (treeHeight - lane.height) / 2
        local laneLeft = options.leftPadding + lane.offset
        for _, treeRoot in ipairs(lane.items) do
            PositionSubtree(treeRoot, rootTop, laneLeft)
            rootTop = rootTop + wrappedLayouts[treeRoot.id].height
                + branchGap
        end
    end

    local requiredWidth = 0
    for _, node in ipairs(nodes) do
        requiredWidth = math.max(requiredWidth,
            horizontalPositions[node.id] + node.layoutWidth
                + options.padding)
    end
    local requiredHeight = options.padding * 2 + treeHeight
    local contentWidth = math.max(options.viewportWidth, requiredWidth)
    local contentHeight = math.max(options.viewportHeight, requiredHeight)

    return {
        horizontalPositions = horizontalPositions,
        verticalPositions = verticalPositions,
        treeHeight = treeHeight,
        requiredWidth = requiredWidth,
        requiredHeight = requiredHeight,
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        treeTop = (contentHeight - treeHeight) / 2,
    }
end
