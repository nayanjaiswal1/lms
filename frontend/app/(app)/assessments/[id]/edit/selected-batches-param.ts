import { parseAsArrayOf, parseAsString } from "nuqs";

export const selectedBatchesParam = parseAsArrayOf(parseAsString).withDefault([]);
