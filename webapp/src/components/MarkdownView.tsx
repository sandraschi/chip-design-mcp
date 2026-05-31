/** Lightweight markdown rendering for help docs (no extra deps). */

function renderInline(text: string) {
  const parts = text.split(/(`[^`]+`)/g);
  return parts.map((part, i) => {
    if (part.startsWith('`') && part.endsWith('`')) {
      return (
        <code key={i} className="text-emerald-400 bg-gray-800 px-1 rounded text-xs">
          {part.slice(1, -1)}
        </code>
      );
    }
    return <span key={i}>{part}</span>;
  });
}

export default function MarkdownView({ markdown }: { markdown: string }) {
  const blocks = markdown.split(/\n(?=## )/);

  return (
    <div className="space-y-6 text-sm text-gray-300 leading-relaxed max-w-4xl">
      {blocks.map((block, bi) => {
        const lines = block.trim().split('\n');
        if (!lines.length) return null;
        const first = lines[0];
        if (first.startsWith('# ')) {
          return (
            <h2 key={bi} className="text-xl font-bold text-white mt-2">
              {first.slice(2)}
            </h2>
          );
        }
        if (first.startsWith('## ')) {
          const body = lines.slice(1);
          return (
            <section key={bi}>
              <h3 className="text-lg font-semibold text-white mb-2">{first.slice(3)}</h3>
              <BlockBody lines={body} />
            </section>
          );
        }
        return (
          <section key={bi}>
            <BlockBody lines={lines} />
          </section>
        );
      })}
    </div>
  );
}

function BlockBody({ lines }: { lines: string[] }) {
  const elements: React.ReactNode[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith('```')) {
      const codeLines: string[] = [];
      i += 1;
      while (i < lines.length && !lines[i].startsWith('```')) {
        codeLines.push(lines[i]);
        i += 1;
      }
      i += 1;
      elements.push(
        <pre
          key={`c-${i}`}
          className="bg-gray-950 border border-gray-800 rounded-lg p-4 text-xs font-mono overflow-x-auto my-3 text-gray-100"
        >
          {codeLines.join('\n')}
        </pre>,
      );
      continue;
    }
    if (line.startsWith('|') && line.includes('|')) {
      const tableLines: string[] = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        tableLines.push(lines[i]);
        i += 1;
      }
      elements.push(<MarkdownTable key={`t-${i}`} rows={tableLines} />);
      continue;
    }
    if (line.match(/^[-*] /)) {
      const items: string[] = [];
      while (i < lines.length && lines[i].match(/^[-*] /)) {
        items.push(lines[i].replace(/^[-*] /, ''));
        i += 1;
      }
      elements.push(
        <ul key={`u-${i}`} className="list-disc list-inside space-y-1 my-2">
          {items.map((item, j) => (
            <li key={j}>{renderInline(item)}</li>
          ))}
        </ul>,
      );
      continue;
    }
    if (line.trim() === '') {
      i += 1;
      continue;
    }
    elements.push(
      <p key={`p-${i}`} className="my-2">
        {renderInline(line)}
      </p>,
    );
    i += 1;
  }
  return <>{elements}</>;
}

function MarkdownTable({ rows }: { rows: string[] }) {
  const parse = (row: string) =>
    row
      .split('|')
      .slice(1, -1)
      .map((c) => c.trim());
  const header = parse(rows[0]);
  const body = rows.slice(2).map(parse);
  return (
    <div className="overflow-x-auto my-3">
      <table className="w-full text-xs border border-gray-800">
        <thead>
          <tr className="bg-gray-800/80">
            {header.map((h) => (
              <th key={h} className="text-left px-3 py-2 text-gray-200">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {body.map((cells, ri) => (
            <tr key={ri} className="border-t border-gray-800">
              {cells.map((c, ci) => (
                <td key={ci} className="px-3 py-2 text-gray-400">
                  {renderInline(c)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
