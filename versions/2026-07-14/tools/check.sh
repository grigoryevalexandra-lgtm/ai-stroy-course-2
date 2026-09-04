#!/bin/bash
# Приёмочная проверка демо-комплекта «30 шагов» (v2, 03.07.2026).
# Запуск из корня репозитория: bash tools/check.sh
FILES=$(ls lesson-*.html module-0.html index.html karta-kursa.html shablon-uroka.html 2>/dev/null)
FAILED=0
for f in $FILES; do
  ERR=""
  grep -q 'name="viewport"' "$f" || ERR="$ERR viewport"
  grep -q 'box-sizing' "$f" || ERR="$ERR box-sizing"
  grep -q 'overflow-x' "$f" || ERR="$ERR overflow-x"
  grep -qi 'noindex' "$f" || ERR="$ERR noindex"
  grep -qE '(localStorage|sessionStorage)\s*(\[|\.(getItem|setItem|removeItem|clear|key))' "$f" && ERR="$ERR !storage"
  # закрыт ли html
  tail -c 50 "$f" | grep -q '</html>' || ERR="$ERR !</html>"
  # баланс section
  o=$(grep -o '<section' "$f" | wc -l); c=$(grep -o '</section>' "$f" | wc -l)
  [ "$o" != "$c" ] && ERR="$ERR section:$o/$c"
  # ссылка на архив материалов (для уроков)
  case "$f" in lesson-*)
    grep -q 'materials/shag-[0-9a-z-]*\.zip' "$f" || ERR="$ERR !matzip";;
  esac
  if [ -n "$ERR" ]; then echo "FAIL $f:$ERR"; FAILED=1; else echo "OK   $f"; fi
done
# все архивы, на которые ссылаются уроки, существуют
for z in $(grep -ho 'materials/shag-[0-9a-z-]*\.zip' lesson-*.html | sort -u); do
  [ -f "$z" ] || { echo "FAIL нет архива: $z"; FAILED=1; }
done
# каждый архив: docx + интерактив
for z in materials/*.zip; do
  L=$(unzip -l "$z")
  echo "$L" | grep -q 'urok-tekst.docx' || { echo "FAIL $z: нет docx"; FAILED=1; }
  echo "$L" | grep -q 'interaktiv' || { echo "FAIL $z: нет интерактивов"; FAILED=1; }
done
# в индексе нет битых url
for u in $(grep -o "url:'[^']*'" index.html | sed "s/url:'//;s/'//" | sort -u); do
  [ -f "$u" ] || { echo "FAIL index: битый url $u"; FAILED=1; }
done
[ $FAILED -eq 0 ] && echo "=== ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ ===" || echo "=== ЕСТЬ ОШИБКИ ==="
exit $FAILED
