import { seed, cleanup, readMetrics, noOp } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export function verifyBulk(ctx, result) {
  ctx.artifact("bulk-results.json", result);
  ctx.metric("soqlCount", result.soqlCount);
  ctx.metric("cpuMs", result.cpuMs);
  const rows = result.outcomes ?? [];
  ctx.check(
    "200 correct per-record outcomes",
    rows.length === 200 &&
      rows.every(
        (row) =>
          row.success === row.expectedAllowed &&
          (row.success ||
            row.errors.some((error) =>
              error.includes(ctx.fixtureKey + " requires completion")
            ))
      ) &&
      rows.filter((row) => row.success).length === 100,
    `${rows.filter((row) => row.success).length} allowed; ${rows.filter((row) => !row.success).length} blocked`
  );
  ctx.check(
    "SOQL budget <= 6 including partial-save retries",
    Number.isInteger(result.soqlCount) &&
      result.soqlCount >= 0 &&
      result.soqlCount <= 6,
    `${result.soqlCount} queries; ${result.cpuMs}ms CPU`
  );
}

export default {
  name: "bulk-200",
  description:
    "Partial save of 200 Accounts against three active rules; 100 complete snapshots.",
  setup: (ctx) => seed(ctx, { count: 200, rules: 3 }),
  run(ctx) {
    const result = readMetrics(
      ctx.runAnonymous(`
      String prefix=${soqlLiteral(ctx.fixtureKey + "%")};
      List<Account> accounts=[SELECT Id, Name FROM Account WHERE Name LIKE :prefix ORDER BY Name];
      List<Account> changes=new List<Account>();
      for (Account account:accounts) changes.add(new Account(Id=account.Id, Rating='Hot'));
      Integer queries=Limits.getQueries(), cpu=Limits.getCpuTime();
      Database.SaveResult[] results=Database.update(changes, false);
      Integer usedQueries=Limits.getQueries()-queries, usedCpu=Limits.getCpuTime()-cpu;
      List<Object> outcomes=new List<Object>();
      for (Integer i=0; i<results.size(); i++) {
        Integer index=Integer.valueOf(accounts[i].Name.substringAfterLast('-'));
        List<String> errors=new List<String>();
        for (Database.Error error:results[i].getErrors()) errors.add(error.getMessage());
        outcomes.add(new Map<String,Object>{'recordId'=>accounts[i].Id, 'index'=>index,
          'expectedAllowed'=>index<100, 'success'=>results[i].isSuccess(), 'errors'=>errors});
      }
      System.debug('CKR_EVIDENCE='+JSON.serialize(new Map<String,Object>{
        'soqlCount'=>usedQueries, 'cpuMs'=>usedCpu, 'outcomes'=>outcomes}));
    `)
    );
    verifyBulk(ctx, result);
  },
  verify: noOp,
  cleanup
};
