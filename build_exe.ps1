# PowerShell Build Script

# This script builds the project and compiles the executable.

# Define paths
$solutionPath = "Path\To\Your\Solution.sln"
$outputPath = "Path\To\Output"

# Build the solution
.
\"$solutionPath\" /p:Configuration=Release /out:"$outputPath"

# Display a message upon success
Write-Host "Build completed successfully!"