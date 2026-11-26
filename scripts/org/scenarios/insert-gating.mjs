import { seed, cleanup, readMetrics, noOp } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export default {
  name: "insert-gating",
  description:
    "Observe before-insert gate behavior without changing enforcement.",
  setup: (ctx) => seed(ctx),
  run(ctx) {
    const result = readMetrics(
      ctx.runAnonymous(`
      Account candidate=new Account(Name=${soqlLiteral(ctx.fixtureKey + "-insert")}, Rating='Hot');
      Database.SaveResult saved=Database.insert(candidate, false);
      List<String> errors=new List<String>();
      for (Database.Error error:saved.getErrors()) errors.add(error.getMessage());
      System.debug('CKR_EVIDENCE='+JSON.serialize(new Map<String,Object>{
        'blocked'=>!saved.isSuccess(), 'errors'=>errors, 'recordId'=>saved.getId()}));
    `)
    );
    ctx.artifact("insert-result.json", result);
    ctx.metric("insertBlocked", result.blocked);
    ctx.metric("exactErrors", result.errors);
    // D3: keep existing behavior; before insert has no record Id/newMap.
    ctx.check(
      "Inserts remain ungated by design (D3)",
      result.blocked === false && result.errors.length === 0,
      JSON.stringify(result)
    );
  },
  verify: noOp,
  cleanup
};
