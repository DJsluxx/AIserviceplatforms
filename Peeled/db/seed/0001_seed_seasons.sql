-- PEELED — Initial seasons seed
insert into seasons (id, slug, name, theme, starts_at, ends_at, config) values
  (1, 'launch', 'Launch Season', 'launch',
    '2026-05-01T00:00:00Z', '2026-06-15T00:00:00Z',
    jsonb_build_object('palette','warm-paper','layer_boost',0.0)),
  (2, 'cosmic_cardboard', 'Cosmic Cardboard', 'cosmic',
    '2026-06-15T00:00:00Z', '2026-07-31T00:00:00Z',
    jsonb_build_object('palette','deep-space','layer_boost',0.1,'featured_rarity','legendary')),
  (3, 'paper_lanterns', 'Paper Lanterns', 'lantern',
    '2026-07-31T00:00:00Z', '2026-09-14T00:00:00Z',
    jsonb_build_object('palette','dusk-glow','dusk_events',true))
on conflict (id) do update
  set name = excluded.name,
      theme = excluded.theme,
      starts_at = excluded.starts_at,
      ends_at = excluded.ends_at,
      config = excluded.config;
