List<Report> reportRows = [SELECT Id, DeveloperName FROM Report WHERE FolderName = 'Checkr Operations'];
System.Assert.areEqual(3, reportRows.size(), 'Expected three packaged reports');
for (Report report : reportRows) {
    Reports.ReportResults result = Reports.ReportManager.runReport(report.Id, false);
    System.Assert.isNotNull(result, 'Report execution returned no result');
    System.debug(LoggingLevel.ERROR, 'CKR_REPORT_RESULT ' + JSON.serialize(new Map<String, Object>{
        'report' => report.DeveloperName,
        'factCount' => result.getFactMap().size(),
        'name' => result.getReportMetadata().getName()
    }));
}
