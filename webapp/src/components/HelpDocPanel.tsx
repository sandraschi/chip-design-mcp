import { useEffect, useState } from 'react';
import { apiGet } from '../lib/api';
import MarkdownView from './MarkdownView';

interface HelpDoc {
  slug: string;
  title: string;
  markdown: string;
}

export default function HelpDocPanel({ slug }: { slug: string }) {
  const [doc, setDoc] = useState<HelpDoc | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    setError(null);
    apiGet<HelpDoc>(`/api/v1/help/${slug}`)
      .then(setDoc)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [slug]);

  if (loading) {
    return <p className="text-gray-500 text-sm">Loading help…</p>;
  }
  if (error) {
    return <p className="text-red-400 text-sm">Failed to load help: {error}</p>;
  }
  if (!doc) return null;

  return (
    <div>
      <p className="text-xs text-gray-500 mb-4 font-mono">{doc.slug}</p>
      <MarkdownView markdown={doc.markdown} />
    </div>
  );
}
