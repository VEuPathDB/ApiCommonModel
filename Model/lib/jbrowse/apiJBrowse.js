/** The "fmtMeta" functions only have the value.  They don't have access to the functions */
function datasetLink(name, display) {
    return "<a  target='_blank' href='/a/app/search/transcript/DatasetsByDatasetNames?param.dataset_name=" + name + "&autoRun=1'>" + display + "</a>";
}

function datasetDescription(summary, trackSpecificText) {
    return "<p>" + trackSpecificText + "</p><p>" + summary + "</p>";
}


