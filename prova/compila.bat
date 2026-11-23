@echo off
rem Compila un documento con LuaLaTeX e apre il PDF.
rem   compila.bat                       compila documento.tex
rem   compila.bat configurazioni.tex    compila quel file
set "NOME=%~n1"
if "%NOME%"=="" set "NOME=documento"
lualatex -interaction=nonstopmode %NOME%.tex
if errorlevel 1 (
  echo.
  echo Errore di compilazione: guarda %NOME%.log
  pause
  exit /b 1
)
start "" %NOME%.pdf
