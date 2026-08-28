# SandPiper Error/Warning Messages

## Message Format

SandPiper messages look like, e.g.:

```
LOGIC_ERROR(5) (UNASSIGNED-SIG): File 'wip.tlv' Line 40 (char 45)
        +-------------------vvvv----------------------------------
        >            $foo = $bar;
        +-------------------^^^^----------------------------------
        Signal |default$bar is used but never assigned.
```

There are several elements to this message that can be clues to the issue:

### Severity and Exit Status

`LOGIC_ERROR(5)` indicates the severity (LOGIC_ERROR), which corresponds to a level (5). SandPiper's exit status is the greatest level of any message.

Severities are:

- (0) DEBUG: Debug message. These are for development only and should not exist in production.
- (0) CONTEXT: Reported prior to another, providing additional related context.
- (0) INFORM: Routine informational message. These are limited to a small core set, or are specifically requested.
- (1) WARNING: Situation warranting review (with information about how to waive the report).
- (2) FIXED_ERROR: Input is invalid, but a reasonable interpretation assumed, with a correction available in scrubbed TLV code.
- (3) SYNTAX_ERROR: Input code syntax is invalid; a (low-confidence) interpretation is assumed and reported, with a correction available in scrubbed TLV code. 
- (4) RECOV_ERROR: Design is, or might be, broken, but program execution can be trusted otherwise.
- (5) LOGIC_ERROR: Code can be generated and valid (compilable) model can be produced, but the logic may not be correct.
- (6) GEN_ERROR: SandPiper execution can continue, but the generated code will not be correct and may not compile.
- (7) RISKY_ERROR: SandPiper is attempting to recover, but this error may lead to others.
- (8) DEFERRED_ERROR: A fatal error, but the current stage of execution can continue before exiting.
- (9) ERROR: Execution continues, but downstream behavior is questionable and results should not be trusted.
- (10) FATAL_ERROR: Cannot recover. Exits immediately.
- (11) BUG: A bug, that can be reported to " + Version.companyName() + ". Execution is allowed to continue, though subsequent errors are likely.
- (12) FATAL_BUG: An unrecoverable bug.

Though many of these are able to produce valid Verilog, all non-zero level messages indicate issues that can and should be addressed, thus `fev.sh` treats them all as fatal.

### Code Block

The code block shows the expression resulting in the message, e.g.:

```
            $foo = $bar;
```

### Location

The location of the error is indicated by, e.g., `File 'wip.tlv' Line 40 (char 45)`. It is also indicated by the `>`, `vvvv`, and `^^^^` arrows, pointing to the element of the code triggering the error.

### Message

The message, e.g., `Signal |default$bar is used but never assigned.`, explains the error.


## Messages

A few common messages deserve additional explanation and are illustrated by the examples below.

### Cross-Pipeline References

```
   |pipe
      @0
         $foo = 1'b0;
   $bar = |pipe$foo;
```

Results in:
```
RECOV_ERROR(4) (NO-ALIGN): File 'top.m4' Line 8 (char 20)
	+-------------------vvvv------------------
	>   $bar = |pipe$foo;
	+-------------------^^^^------------------
	Cross-pipeline signal references require explicit alignment.  Zero assumed.
```

`$bar` is in a default (unamed pipeline) which has independent stage numbering from `|pipe`. When referencing from one pipeline into another, an alignment identifier (e.g., `<<2`, `>>1`, or `<>0`) must be provided to identify the source pipestage, relative to the assignment's stage.

The fix in this case might be:
```
   |pipe
      @0
         $foo = 1'b0;
   $bar = |pipe<>0$foo;
```

### Malformed Identifier

Using a pipeline, like `|i_pipe` results in:

```
FATAL_ERROR(10) (PARSE-IDENT): File 'top.m4' Line 5 (char 4)
	+---v-------------------------------------
	>   |i_pipe
	+---^-------------------------------------
	Malformed identifier "|i_pipe"
```

Scopes (including pipelines) have restricted naming conventions, just like pipesignals. These restrictions are described by `./scripts/get_task.py 'Naming Conventions'`.

### Used Before Assigned

Slightly modifying the above example:

```
   |pipe
      @1
         $foo = 1'b0;
   $bar = |pipe<>0$foo;
```

Results in:

```
DEFERRED_ERROR(8) (EARLY-USE): File 'top.m4' Line 8 (char 11)
	+----------vvvvvvvvvvvv-------------------
	>   $bar = |pipe<>0$foo;
	+----------^^^^^^^^^^^^-------------------
	Signal |pipe$foo is used earlier than it is assigned.
```

Here, `|pipe<>0$foo` references `|pipe$foo` at stage `@0`. (Statements outside of an explicit pipeline are in stage `@0` of a default pipeline, and `@0` offset by `<>0` is `@0`.) This is attempting to access |pipe$foo a stage before its assignment.

You might encounter this for the `.eqy` match section as well. The use of SandPiper for the match section has the match section in the default (not `|default`) pipeline, so references into pipelines need explicit alignment, e.g. `<>0$foo`.

### Bug While Converting If to For

```
\TLV
   /gen[1 : 0]
   \SV_plus
      assign /gen[0]$$sig = 1'b0;
```

Results in:

BUG(11) (BUG):
        Failed to find declaration scope for |default/gen_immdec_w_eq4$rd_addr

Yep, this is a SandPiper bug. It happens because we're doing strange things to convert `for` loops to TLV scopes replicated 0 or 1 times.

The resolution is to continue past this intermediate state to:

```
\TLV
   /gen[1 : 0]
      $sig = 1'b0;
   \SV_plus
```
