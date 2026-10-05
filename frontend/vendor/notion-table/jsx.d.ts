import type { Column, Row, NotionTable } from "./notion-table";

// React 19 passes object props straight to custom-element properties.
declare module "react" {
  namespace JSX {
    interface IntrinsicElements {
      "notion-table": React.DetailedHTMLProps<React.HTMLAttributes<NotionTable>, NotionTable> & {
        columns?: Column[];
        rows?: Row[];
        readonly?: boolean;
      };
    }
  }
}
