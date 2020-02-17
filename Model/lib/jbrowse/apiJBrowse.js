/** The "fmtMeta" functions only have the value.  They don't have access to the functions */
function datasetLink(name, display) {
    return "<a  target='_blank' href='/a/processQuestion.do?questionFullName=DatasetQuestions.DatasetsByDatasetNames&dataset_name=" + name + "&questionSubmit=Get+Answer'>" + display + "</a>";
}

function datasetDescription(summary, trackSpecificText) {
    return "<p>" + trackSpecificText + "</p><p>" + summary + "</p>";
}

