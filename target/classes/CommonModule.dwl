/**
* Helpers shared by the three BASF inbound mappings (IFTMIN, IFTMBF, IFCSUM).
*
* Two navigation styles live here and both are needed:
*
*   - Positional selectors ("0020_BGM") are what IftminModule uses. They are exact for a
*     known directory and read naturally, but the position numbers are directory-specific.
*   - Suffix navigation (`segs`/`seg1`/`groupsWith`) matches a segment by its "_<TAG>" key
*     suffix and walks groups structurally, so it survives a directory change. IftmbfModule
*     and IfcsumModule use it, because D08A renumbers almost every group relative to D99A
*     and two group numbers collide with a *different* meaning across the two directories.
*
* DataWeave 2.9 notes that this file depends on: `input` is a reserved word; the strict
* type-checker rejects concrete return-type annotations on functions whose bodies are
* Any-typed JSON selectors, so most helpers are left un-annotated - except `asArray` and
* `kvs`, which must be annotated `Array<Any>` for the `flatMap` chains below to type-check.
*/

// ===========================================================================
// Scalars
// ===========================================================================

/** True when `v` is neither null nor blank. */
fun present(v) = v != null and (trim(v as String default "")) != ""

/** Numeric value of `v`, or 0 when absent/unparseable. */
fun num(v) = if (v == null) 0 else (trim(v as String) as Number default 0)

/** Empty / all-blank text -> null, else the value. */
fun nz(v) = if (present(v)) v else null

/** CCYYMMDD... -> YYYY-MM-DD (null when too short). */
fun toIsoDate(v) = do {
    var str = (v default "") as String
    ---
    if (sizeOf(str) < 8) null
    else (str[0 to 3] default "") ++ "-" ++ (str[4 to 5] default "") ++ "-" ++ (str[6 to 7] default "")
}

/** CCYYMMDDHHMM (format 203) -> YYYY-MM-DDTHH:mm:ss; a date-only value -> ...T00:00:00. */
fun toIsoDateTime(v) = do {
    var str = (v default "") as String
    var d = toIsoDate(v)
    ---
    if (d == null) null
    else if (sizeOf(str) >= 12) d ++ "T" ++ (str[8 to 9] default "") ++ ":" ++ (str[10 to 11] default "") ++ ":00"
    else d ++ "T00:00:00"
}

// ===========================================================================
// Carlo JSON rendering
// ===========================================================================

/** PascalCase -> camelCase on a single key (Customer->customer, DUNSCustomer->dUNSCustomer). */
fun lowerFirst(s) = do {
    var str = s as String
    ---
    if (sizeOf(str) <= 1) lower(str)
    else lower(str[0 to 0]) ++ str[1 to -1]
}

/**
* Recursively lower-case the first letter of every object key.
*
* The mappings are authored in PascalCase because that is what the Carlo mapping sheets
* and the v3 XML schema use, but Carlo's JSON deserializer is case-sensitive and expects
* camelCase. Uploading PascalCase JSON makes Carlo silently ignore every field.
*/
fun camelKeys(v) = v match {
    case o is Object -> o mapObject ((val, key) -> { (lowerFirst(key)): camelKeys(val) })
    case a is Array -> a map ((e) -> camelKeys(e))
    else -> v
}

// ===========================================================================
// Suffix navigation (directory-independent)
// ===========================================================================

/** `v` as an array: an array stays, null becomes [], anything else is wrapped. */
fun asArray(v): Array<Any> = v match {
    case a is Array -> a
    case n is Null -> []
    else -> [v]
}

/** The key/value pairs of `node` as an array; null-safe, which makes every chain below null-safe. */
fun kvs(node): Array<Any> = node match {
    case o is Object -> o pluck ((value, key) -> { k: key as String, v: value })
    case n is Null -> []
    else -> []
}

/** Direct-child segments of `node` named `name`, always as an array (possibly empty). */
fun segs(node, name) =
    kvs(node) filter ((e) -> e.k endsWith ("_" ++ name)) flatMap ((e) -> asArray(e.v))

/** The first direct-child segment of `node` named `name`, or null. */
fun seg1(node, name) = segs(node, name)[0]

/** Every direct-child segment-group repeat of `node`, flattened. */
fun subGroups(node) =
    kvs(node) filter ((e) -> e.k contains "_Segment_group_") flatMap ((e) -> asArray(e.v))

/**
* The direct-child group repeats of `node` identified by a segment they carry.
*
* Only *direct* children are considered, so a party group nested two levels down inside an
* equipment group can never be mistaken for a header party group.
*/
fun groupsWith(node, name) = subGroups(node) filter ((g) -> !isEmpty(segs(g, name)))

/** Business-content root of a parsed message: `Heading` in every capture, else the message. */
fun body(doc) = doc.Heading default doc

// ===========================================================================
// Interchange access
// ===========================================================================

/**
* Every parsed message of type `msgType` in the interchange, in order, across whichever
* directory version the sender used.
*
* The parser nests messages as EDI.Messages.<DIRECTORY>.<TYPE>[]. Reading the directory
* level generically rather than hard-coding D99A/D08A means a directory bump does not
* silently yield zero messages - and it is what lets one mapping handle a master-sub
* interchange, which carries several messages of the same type under the same directory.
*/
fun messagesOfType(doc, msgType) =
    kvs(doc.EDI.Messages) flatMap ((dir) -> asArray(dir.v[msgType]))

// ===========================================================================
// FTX free text
// ===========================================================================

/** The non-null text components FTX0401..FTX0405 of one FTX object, in order. */
fun ftxParts(f) =
    [f.FTX0401, f.FTX0402, f.FTX0403, f.FTX0404, f.FTX0405]
        filter ((x) -> x != null) map ((x) -> x as String)

/** The FTX entries in `arr` whose qualifier FTX01 == `q`. */
fun ftxOf(arr, q) = (arr default []) filter ((f) -> f.FTX01 == q)

/**
* Aggregate every FTX carrying qualifier `q`: join one entry's components with `compSep`
* (components are a wrapped continuation of one sentence, so this is normally ""), then
* join repeated entries with `segSep`.
*/
fun ftxAgg(arr, q, compSep, segSep) = do {
    var t = (ftxOf(arr, q) map ((f) -> ftxParts(f) joinBy compSep)) joinBy segSep
    ---
    nz(t)
}
