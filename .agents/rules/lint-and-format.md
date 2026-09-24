# Lint and Format Rules

Every rule below is enforced by a config file in the repository root. Keep this file in sync when a config changes (docsync tracks it).

| Tool | Config | Run |
|------|--------|-----|
| SwiftFormat | `.swiftformat` | `mise run format` |
| SwiftLint | `.swiftlint.yml` | `mise run lint` (`--strict`, so warnings fail) |
| my-swift-linter (AST lint) | `.my-swift-linter.yml` | `mise run ast-lint` / `mise run ast-fix` |

The tool versions in `.mise.toml` track the latest releases (`mise run setup` bumps them), so the effective rule set is intentionally stricter than a project that pins older tools: rules that newer versions enable by default are followed, not disabled. When a bump turns on a new default rule, fix the code and document the rule here.

If you add a rule exception to any of these configs, update this file and note the reason in `CLAUDE.md`.

## SwiftFormat (`.swiftformat`)

- `--swiftversion` matches the package's Swift tools version.
- `--indent 4`: four-space indentation.
- `--indentcase false`: `case` labels align with their `switch`.
- `--stripunusedargs closure-only`: unused arguments become `_` in closures only, never in function signatures.
- `--disable redundantSwiftTestingSuite`: keep explicit `@Suite` attributes.
- `--disable swiftTestingTestCaseNames`: SwiftFormat does not rename `@Test` functions; naming is enforced by the AST linter instead.
- Excluded: `.build`, `.swiftpm`, and any nested `**/.build/**` / `**/.swiftpm/**`.
- All other SwiftFormat default rules apply, including these, which are on by default since SwiftFormat 0.63:
  - `wrapIfStatementBodies`: the body of an `if` statement goes on its own line (`if foo { return bar }` is wrapped).
  - `wrapIfExpressionBodies`: the branches of an `if` expression go on their own lines (`let x = if c { a } else { b }` is wrapped).
  - `redundantSwiftUIGroup`: a SwiftUI `Group` used only as a builder wrapper is removed in favor of `@ViewBuilder`.

## SwiftLint (`.swiftlint.yml`)

Linted paths: `Sources`, `Tests`, `Package.swift`. Excluded: `.build`, `.swiftpm`, `**/.build/**`, `**/.swiftpm/**`. Runs with `--strict`, so every warning is an error.

Disabled rules (either SwiftFormat owns the style, or the AST linter covers the concern differently):

`trailing_comma`, `opening_brace`, `modifier_order`, `trailing_whitespace`, `vertical_whitespace`, `colon`, `void_return`, `comma`, `prefer_self_in_static_references`, `redundant_nil_coalescing`, `force_unwrapping`, `force_try`, `identifier_name`, `line_length`, `type_body_length`, `file_length`, `function_body_length`, `cyclomatic_complexity`, `large_tuple`, `trailing_closure`, `unneeded_synthesized_initializer`, `for_where`, `redundant_discardable_let`, `optional_data_string_conversion`, `enum_case_associated_values_count`.

Configured thresholds:

- `type_name`: 3-60 characters.
- `nesting`: types nest at most 3 levels deep; functions nest at most 5 levels deep.
- `function_parameter_count`: warning at 8 parameters, error at 10 (with `--strict`, 8 already fails).

Every other SwiftLint default rule is active, including `legacy_swiftui_aspect_ratio` (on by default since SwiftLint 0.65.1): prefer `scaledToFit()` / `scaledToFill()` over `aspectRatio(contentMode:)` with a constant content mode.

## AST Lint (`.my-swift-linter.yml`, my-swift-linter)

`.my-swift-linter.yml` is the file my-swift-linter 0.14.0 reads by default. Scripts still pass `--config` explicitly.

Linted paths: `Sources/**/*.swift`, `Tests/**/*.swift`. Excluded: `.build/**`, `.swiftpm/**`, `**/.build/**`, `**/.swiftpm/**`, `**/Generated/**`, `**/Fixtures/**`. All rules are errors.

- **`deep-nesting`**: control flow (`if`, `guard`, `for`, `while`, `switch`, `do`) may nest at most 3 levels; depth 4 fails. Depth resets at function, initializer, accessor, and closure boundaries. Extract a helper instead of nesting deeper.
- **`single-large-type-per-file`**: at most one `public`/`package` type (enum, struct, class, actor) of 50 or more lines per file. Split the others into their own files. `*Generated.swift` and `Fixtures/` are exempt.
- **`property-declaration-ordering`**: within a type, properties are grouped by property wrapper (alphabetically, unwrapped properties last), then by access modifier within each group. Autofixable.
- **`function-access-modifier-grouping`**: within a type, functions are ordered by access, `open` → `public` → `package` → `internal` → `fileprivate` → `private`. `init`, `deinit`, and `subscript` are exempt. Autofixable.
- **`swiftui-view-property`**: no `return` in `some View` properties, and `@ViewBuilder` is required when the body has top-level `let`/`var`/`if`/`switch`.
- **`branch-assignment-to-tuple`**: no uninitialized `let` followed by an `if`/`switch` that assigns it in every branch. Use an expression-form `let x = if … else …` / `let x = switch …`.
- **`no-top-level-function`**: no `func` at file scope. Put helpers on a type, in an extension, or in a caseless namespace `enum`.
- **`return-if-expression`**: when every branch of an `if`/`else` is a single `return <expr>`, write `return if … else …`.
- **`return-switch-expression`**: when every `case` is a single `return <expr>`, write `return switch …`.
- **`use-url-file-path`**: use `URL(filePath:)`, not the deprecated `URL(fileURLWithPath:)`.
- **`meaningful-suite-description`** (on by default): a `@Suite("…")` description must not just repeat the type name (with or without a `Tests`/`Test`/`Spec` suffix).
- **`test-function-naming`** (on by default): `@Test` functions use lowerCamelCase, with no `test` prefix, no underscores, and no backtick-quoted phrases. Put the sentence in `@Test("…")`.
- **`test-description-duplicates-name`** (on by default): `@Test`/`@Suite` descriptions must add information and not just spell out the camelCase name with spaces.
- **`collapsible-if`** (on by default since my-swift-linter 0.14): an `if`/`guard` whose body is only a single `if` with no `else` must be merged into one condition list with `,`. Not flagged when either `if` has an `else`, the outer body has other statements, or the outer `if` is labeled.
- **`hoist-repeated-instance`** (on by default since my-swift-linter 0.14): the same `JSONDecoder`, `JSONEncoder`, `PropertyListDecoder`, `PropertyListEncoder`, `DateFormatter`, `NumberFormatter`, `DateComponentsFormatter`, `DateIntervalFormatter`, or `PersonNameComponentsFormatter` constructed (and identically configured, or left unconfigured) as a local in two or more instance members of one type must be hoisted to a single stored property.
- **`missing-docs`**: every declaration with `package` or wider access under `Sources/<Package>Kit/**` needs a `///` doc comment. Exempt: all `init`s, `enum CodingKeys`, `var errorDescription`, `func ==`, and result-builder / interpolation hooks (`buildBlock`, `buildExpression`, `buildOptional`, `buildEither`, `buildArray`, `appendLiteral`, `appendInterpolation`). `*Generated.swift` is exempt.

Run `mise run ast-fix` to apply the available autofixes, then review the diff.
