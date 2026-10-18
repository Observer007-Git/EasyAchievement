local _, Addon = ...

Addon.Config = {
    Frame = {
        DefaultWidth = 900,
        DefaultHeight = 650,
        MinWidth = 860,
        MinHeight = 420,
        MaxWidth = 1500,
        MaxHeight = 1000,
    },
    Tree = {
        NodeSize = 20,
        NodeIconSize = 17,
        BranchGap = 1,
        LevelGap = 8,
        LabelLeftGap = 4,
        Padding = 10,
        MinScale = 0.2,
        MaxScale = 1.5,
        ScaleStep = 0.01,
    },
    Card = {
        MinScale = 0.5,
        MaxScale = 2,
        ScaleStep = 0.01,
    },
    Search = {
        MaxResults = 8,
    },
    ModelScene = {
        DressUpSceneID = 596,
    },
    Performance = {
        IndexBudgetMilliseconds = 2,
        ResizeLayoutInterval = 0.05,
        CriteriaRefreshDelay = 0.05,
    },
    State = {
        MaxTreeStates = 50,
        MaxHistoryEntries = 100,
    },
}
