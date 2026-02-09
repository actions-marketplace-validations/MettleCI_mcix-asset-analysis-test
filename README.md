# MCIX Asset Analysis Test GitHub Action

Run **MCIX asset-level static analysis** for IBM DataStage NextGen inside your GitHub workflows.

This action wraps the `mcix asset-analysis test` command, letting you run MCIX compliance checks against one or more DataStage assets as part of CI/CD.

> Namespace: `asset-analysis`  
> Action: `test`  
> Usage: `DataMigrators/mcix/asset-analysis/test@v1`

## 🚀 Usage

```yaml
- uses: DataMigrators/mcix/asset-analysis/test@v1
  with:
    api-key: ${{ secrets.MCIX_API_KEY }}
    url: https://your-mcix-server/api
    user: datastage.dev
    project: MyDataStageProject
    assets: ./datastage/assets
    report: asset-analysis
```

## 🔧 Inputs

| Name         | Required | Description |
|--------------|----------|-------------|
| api-key      | Yes      | API key for MCIX |
| url          | Yes      | MCIX base URL |
| user         | Yes      | Logical MCIX user |
| assets       | Optional | Paths to assets |
| project      | Conditional | Project name |
| project-id   | Conditional | Project ID |
| report       | Optional | Ruleset/report name |

## 📤 Outputs

| Name | Description |
|------|-------------|
| return-code | Exit code from MCIX |

## 📚 More information

See https://docs.mettleci.io
