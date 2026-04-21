# Builder helpers for Grafana dashboards as typed Nix attrsets.
{ lib }:

{
  # Grid position builder
  gridPos =
    {
      x ? 0,
      y ? 0,
      w ? 12,
      h ? 8,
    }:
    { inherit x y w h; };

  # Standard datasource references
  mimirDS = { uid = "mimir"; type = "prometheus"; };
  lokiDS  = { uid = "loki";  type = "loki"; };
  tempoDS = { uid = "tempo"; type = "tempo"; };

  # Generic datasource reference
  datasource = uid: type: { inherit uid type; };

  # Query target builder
  target =
    {
      expr,
      legendFormat ? "",
      refId ? "A",
    }:
    { inherit expr legendFormat refId; };

  # Timeseries panel builder
  timeseriesPanel =
    {
      id,
      title,
      ds,
      targets,
      gridPos,
    }:
    {
      inherit id title targets gridPos;
      type = "timeseries";
      datasource = ds;
    };

  # Logs panel builder
  logsPanel =
    {
      id,
      title,
      ds,
      targets,
      gridPos,
    }:
    {
      inherit id title targets gridPos;
      type = "logs";
      datasource = ds;
    };

  # Dashboard builder with sensible defaults
  mkDashboard =
    {
      uid,
      title,
      panels,
      refresh ? "30s",
      timeFrom ? "now-1h",
      timeTo ? "now",
    }:
    {
      id = null;
      inherit uid title panels refresh;
      timezone = "browser";
      schemaVersion = 39;
      version = 1;
      time = {
        from = timeFrom;
        to = timeTo;
      };
    };
}
