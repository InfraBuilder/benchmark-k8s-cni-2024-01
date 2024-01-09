# Benchmark Results Visualization

## How to test with sample data

```bash
# Start the stack
docker compose up -d

# Wait for the stack to be ready
sleep 30

# Import data from exomonitor sample
./import-data.sh exomonitor
```

Then open your browser on : [Grafana Explorer](http://localhost:3000/explore?schemaVersion=1&panes=%7B%223wm%22:%7B%22datasource%22:%22P4169E866C3094E38%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22exomonitor_cpu_seconds_total%7Bstate%3D%5C%22idle%5C%22,cpu%3D%5C%22cpu0%5C%22,benchmark%3D%5C%22test%5C%22,job%3D%5C%22exomonitor%5C%22%7D%22,%22range%22:true,%22instant%22:false,%22datasource%22:%7B%22type%22:%22prometheus%22,%22uid%22:%22P4169E866C3094E38%22%7D,%22editorMode%22:%22code%22,%22legendFormat%22:%22__auto%22,%22interval%22:%221s%22,%22format%22:%22table%22%7D%5D,%22range%22:%7B%22from%22:%221704067140000%22,%22to%22:%221704067226000%22%7D%7D%7D&orgId=1)

