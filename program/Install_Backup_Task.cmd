@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "TASK_NAME=AKSoft TeleBackup"
set "EXE_NAME=TeleBackup.exe"
set "VBS_SCRIPT=launch_telebackup.vbs"

:: Главное меню
if "%~1"=="" (
    call :main_menu
    exit /b
)

:: Обработка параметров командной строки
if "%~1"=="install" (
    call :install
) else if "%~1"=="uninstall" (
    call :uninstall
) else if "%~1"=="diagnose" (
    call :diagnose
) else if "%~1"=="run" (
    call :run_task
) else if "%~1"=="status" (
    call :status
) else if "%~1"=="help" (
    call :show_help
) else (
    echo Неизвестная команда: %~1
    call :show_help
)

exit /b

:main_menu
cls
echo ========================================
echo    AKSoft TeleBackup - Менеджер заданий
echo ========================================
echo.
echo 1 - Установить задание
echo 2 - Удалить задание
echo 3 - Запустить задание сейчас
echo 4 - Проверить статус
echo 5 - Диагностика системы
echo 6 - Справка
echo 7 - Выход
echo.
set /p choice="Выберите действие: "

if "!choice!"=="1" (
    call :install
) else if "!choice!"=="2" (
    call :uninstall
) else if "!choice!"=="3" (
    call :run_task
) else if "!choice!"=="4" (
    call :status
) else if "!choice!"=="5" (
    call :diagnose
) else if "!choice!"=="6" (
    call :show_help
) else if "!choice!"=="7" (
    exit /b
) else (
    echo Неверный выбор!
    timeout /t 2 /nobreak >nul
    call :main_menu
)

exit /b

:install
echo.
echo ============ УСТАНОВКА ============
echo.

:: Проверка наличия EXE файла
if not exist "!EXE_NAME!" (
    echo ❌ ОШИБКА: !EXE_NAME! не найден!
    echo Текущая папка: %CD%
    echo.
    pause
    exit /b 1
)

echo ✓ !EXE_NAME! найден
echo.

:: ВЫБОР РЕЖИМА ОКНА
:select_window_mode
echo Выберите режим отображения окна:
echo 1 - Скрытый режим (рекомендуется)
echo 2 - Видимый режим (для отладки)
set /p window_mode=

if "!window_mode!"=="1" (
    set WINDOW_MODE=0
    set WINDOW_DESC=Скрытый
    call :create_vbs_script
) else if "!window_mode!"=="2" (
    set WINDOW_MODE=1
    set WINDOW_DESC=Видимый
    call :create_vbs_script
) else (
    echo Неверный выбор! Попробуйте снова.
    goto select_window_mode
)

echo.
echo Выберите тип бэкапа:
echo 1 - Полный бэкап (--full)
echo 2 - Только создание бэкапа (--backup)
echo 3 - Только загрузка (--upload) (потом отредактировать файл telebackup_args.txt: добавить --file file1.docx)
echo 4 - Только очистка (--cleanup)
set /p backup_type=

set args=--full
set description=Полный цикл бэкапа

if "!backup_type!"=="1" (
    set args=--full
    set description=Полный цикл бэкапа
) else if "!backup_type!"=="2" (
    set args=--backup
    set description=Только создание бэкапа
) else if "!backup_type!"=="3" (
    set args=--upload
    set description=Только загрузка в Telegram
) else if "!backup_type!"=="4" (
    set args=--cleanup
    set description=Только очистка старых бэкапов
) else (
    echo Используется полный бэкап по умолчанию
)

echo.
echo Выберите расписание:
echo 1 - Ежедневно
echo 2 - Еженедельно
echo 3 - Ежемесячно
set /p schedule_choice=

set schedule=daily
set schedule_desc=Ежедневно

if "!schedule_choice!"=="1" (
    set schedule=daily
    set schedule_desc=Ежедневно
) else if "!schedule_choice!"=="2" (
    set schedule=weekly
    set schedule_desc=Еженедельно
) else if "!schedule_choice!"=="3" (
    set schedule=monthly
    set schedule_desc=Ежемесячно
) else (
    echo Используется ежедневное расписание по умолчанию
)

echo.
set /p run_missed="Запускать задачу немедленно, если пропущен плановый запуск? (Y/N): "
if /i "!run_missed!"=="Y" (
    set missed_options=/z
    set missed_desc= (с запуском пропущенных)
) else (
    set missed_options=
    set missed_desc=
)

echo.
echo Настройка принудительного бэкапа:
set /p force_backup="Принудительно создавать бэкап, даже если файлы не изменились? (Y/N): "

if /i "!force_backup!"=="Y" (
    set args=!args! --force
    set force_desc= (принудительно)
) else (
    set force_desc=
)

:: Сохраняем аргументы для VBS скрипта
echo !args! > telebackup_args.txt
echo ✓ Аргументы сохранены

echo.
echo Создание задания...
:: ВАШЕ РЕШЕНИЕ - wscript.exe в программе, VBS в аргументах
schtasks /create /sc !schedule! /tn "!TASK_NAME!" /tr "wscript.exe \"%CD%\!VBS_SCRIPT!\"" /ru "%USERNAME%" !missed_options! /f

if !errorlevel! equ 0 (
    echo.
    echo ✓ Задание успешно создано!
    echo.
    echo 📋 Информация:
    echo    Имя: !TASK_NAME!
    echo    Тип: !description!!force_desc!
    echo    Режим окна: !WINDOW_DESC!
    echo    Расписание: !schedule_desc!!missed_desc!
    echo    Программа: wscript.exe
    echo    Аргументы: "%CD%\!VBS_SCRIPT!"
    echo    Параметры: !args!
    echo    Пользователь: %USERNAME%
    echo.
    
    :: Тестовый запуск
    echo 🔍 Тестовый запуск...
    call :run_task
) else (
    echo.
    echo ❌ Ошибка создания задания!
    echo Запустите от имени администратора
)

echo.
pause
exit /b

:create_vbs_script
echo Создание VBS скрипта для !WINDOW_DESC! режима...

(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo strPath = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"^)^)
echo WshShell.CurrentDirectory = strPath
echo.
echo ' Читаем аргументы из файла
echo Set fso = CreateObject("Scripting.FileSystemObject"^)
echo If fso.FileExists("telebackup_args.txt"^) Then
echo     Set file = fso.OpenTextFile("telebackup_args.txt", 1^)
echo     args = file.ReadLine
echo     file.Close
echo Else
echo     args = "--full"
echo End If
echo.
echo ' Запускаем программу
echo WshShell.Run "TeleBackup.exe " ^& args, !WINDOW_MODE!, False
echo Set WshShell = Nothing
echo Set fso = Nothing
) > "!VBS_SCRIPT!"

echo ✓ VBS скрипт создан: !WINDOW_DESC! режим
exit /b

:uninstall
echo.
echo ============ УДАЛЕНИЕ ============
echo.
echo Удаляем задание "!TASK_NAME!"...
schtasks /delete /tn "!TASK_NAME!" /f

if !errorlevel! equ 0 (
    echo ✓ Задание успешно удалено!
) else (
    echo ⚠ Задание не найдено или ошибка удаления
)

:: Удаляем VBS скрипт и файл аргументов
if exist "!VBS_SCRIPT!" (
    del "!VBS_SCRIPT!"
    echo ✓ VBS скрипт удален
)

if exist "telebackup_args.txt" (
    del "telebackup_args.txt"
    echo ✓ Файл аргументов удален
)

echo.
pause
exit /b

:run_task
echo.
echo ============ ЗАПУСК ============
echo.
echo Запускаем задание "!TASK_NAME!"...
schtasks /run /tn "!TASK_NAME!"

if !errorlevel! equ 0 (
    echo ✓ Задание запущено!
    echo.
    echo 📝 Мониторинг логов:
    echo    Логи программы: backup.log
    echo    Логи планировщика: taskschd.msc
) else (
    echo ❌ Ошибка запуска задания!
)

echo.
timeout /t 3 /nobreak >nul
call :status
exit /b

:status
echo.
echo ============ СТАТУС ============
echo.
schtasks /query /tn "!TASK_NAME!" 2>nul
if !errorlevel! equ 0 (
    echo.
    echo 📊 Детальная информация:
    schtasks /query /tn "!TASK_NAME!" /fo list | findstr /i "status\|last\|next\|task to run"
) else (
    echo ❌ Задание "!TASK_NAME!" не найдено!
)

:: Показываем информацию о режиме окна
if exist "!VBS_SCRIPT!" (
    echo.
    echo 📋 Режим окна: 
    findstr /i "WshShell.Run" "!VBS_SCRIPT!" | findstr /i "0" >nul && echo   Скрытый режим (0) || echo   Видимый режим (1)
)

echo.
pause
exit /b

:diagnose
echo.
echo ============ ДИАГНОСТИКА ============
echo.

echo 1. 📁 Проверка файлов:
if exist "!EXE_NAME!" (
    echo ✓ !EXE_NAME! - найден
) else (
    echo ❌ !EXE_NAME! - не найден!
)

if exist "config.yaml" (
    echo ✓ config.yaml - найден
) else (
    echo ❌ config.yaml - не найден!
)

if exist "!VBS_SCRIPT!" (
    echo ✓ !VBS_SCRIPT! - найден
    findstr /i "WshShell.Run" "!VBS_SCRIPT!" | findstr /i "0" >nul && echo   Режим: Скрытый (0) || echo   Режим: Видимый (1)
) else (
    echo ❌ !VBS_SCRIPT! - не найден!
)

if exist "telebackup_args.txt" (
    echo ✓ telebackup_args.txt - найден
    set /p args=<telebackup_args.txt
    echo   Аргументы: !args!
)

echo.
echo 2. 🔍 Проверка задания:
schtasks /query /tn "!TASK_NAME!" 2>nul
if !errorlevel! equ 0 (
    echo ✓ Задание "!TASK_NAME!" существует
    echo.
    echo 3. 📋 Информация о задании:
    schtasks /query /tn "!TASK_NAME!" /fo list | findstr /i "status\|last\|next\|task to run"
) else (
    echo ❌ Задание "!TASK_NAME!" не найдено
)

echo.
echo 4. 👤 Текущий пользователь: %USERNAME%
echo 5. 📂 Текущая папка: %CD%
echo.

echo 6. 🚀 Тестовый запуск EXE:
echo    Запускаем: !EXE_NAME! --help
echo.
"!EXE_NAME!" --help 2>&1 | more
if !errorlevel! equ 0 (
    echo ✓ EXE файл работает корректно
) else (
    echo ❌ EXE файл не запускается!
)

echo.
pause
exit /b

:show_help
echo.
echo ============ СПРАВКА ============
echo.
echo Использование:
echo   TeleBackup_Manager.cmd install     - Установить задание
echo   TeleBackup_Manager.cmd uninstall   - Удалить задание
echo   TeleBackup_Manager.cmd run         - Запустить задание сейчас
echo   TeleBackup_Manager.cmd status      - Показать статус задания
echo   TeleBackup_Manager.cmd diagnose    - Диагностика системы
echo   TeleBackup_Manager.cmd help        - Эта справка
echo.
echo Без параметров - интерактивное меню
echo.
echo 💡 Особенности:
echo   - Задание создается с wscript.exe для надежного запуска VBS
echo   - Поддержка скрытого и видимого режимов
echo   - Автоматическое сохранение аргументов
echo   - Полная диагностика системы
echo.
pause
exit /b