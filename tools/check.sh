#!/bin/bash
# Приёмочная проверка комплекта «30 шагов» (v3, 04.09.2026).
# Запуск из корня репозитория: bash tools/check.sh
FILES=$(ls lesson-*.html module-0.html index.html karta-kursa.html shablon-uroka.html 2>/dev/null)
FAILED=0
for f in $FILES; do
  ERR=""
  grep -q 'name="viewport"' "$f" || ERR="$ERR viewport"
  grep -q 'box-sizing' "$f" || ERR="$ERR box-sizing"
  grep -q 'overflow-x' "$f" || ERR="$ERR overflow-x"
  grep -qi 'noindex' "$f" || ERR="$ERR noindex"
  grep -qE 'sessionStorage\s*(\[|\.(getItem|setItem|removeItem|clear|key))' "$f" && ERR="$ERR !sessionStorage"
  grep -nE 'localStorage\s*(\[|\.(getItem|setItem|removeItem|clear|key))' "$f" | grep -vq 'course-interactive:' && ERR="$ERR !unexpected-storage"
  grep -qE '(sendRev|dDownloadBtn|zadanie-[^[:space:]]*\.txt|shag-[0-9]+-zadanie\.txt)' "$f" && ERR="$ERR !result-download"
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
# Новая версия хранит старую публикацию как самостоятельный статический сайт.
[ -f versions/index.html ] || { echo "FAIL нет страницы выбора версий"; FAILED=1; }
[ -f versions/2026-07-14/index.html ] || { echo "FAIL нет архивной версии 2026-07-14"; FAILED=1; }
grep -q 'versions/index.html' index.html || { echo "FAIL в индексе нет ссылки на версии"; FAILED=1; }
# Для 35 заданий должны существовать автономные интерактивы.
set -- interactives/lesson-*.html
if [ -e "$1" ]; then ICOUNT=$#; else ICOUNT=0; fi
[ "$ICOUNT" -eq 35 ] || { echo "FAIL interactives: ожидалось 35, найдено $ICOUNT"; FAILED=1; }
grep -RqiE 'Скачать мо[её] задание' interactives && { echo "FAIL interactives: осталось скачивание задания"; FAILED=1; }
grep -RqF 'Проверка не сработала? Сравнить с примером решения' interactives || { echo "FAIL interactives: не найдена согласованная механика"; FAILED=1; }
# все архивы, на которые ссылаются уроки, существуют
for z in $(grep -ho 'materials/shag-[0-9a-z-]*\.zip' lesson-*.html | /usr/bin/sort -u); do
  [ -f "$z" ] || { echo "FAIL нет архива: $z"; FAILED=1; }
done
# каждый архив: docx + интерактив
for z in materials/*.zip; do
  L=$(unzip -l "$z")
  echo "$L" | grep -q 'urok-tekst.docx' || { echo "FAIL $z: нет docx"; FAILED=1; }
  echo "$L" | grep -q 'interaktiv' || { echo "FAIL $z: нет интерактивов"; FAILED=1; }
done
# в индексе нет битых url
for u in $(grep -o "url:'[^']*'" index.html | sed "s/url:'//;s/'//" | /usr/bin/sort -u); do
  [ -f "$u" ] || { echo "FAIL index: битый url $u"; FAILED=1; }
done
[ $FAILED -eq 0 ] && echo "=== ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ ===" || echo "=== ЕСТЬ ОШИБКИ ==="
exit $FAILED
