# Memory leak with popular Stream.toList()

Strumienie wrzawie są bardzo popularną metodą obróbki danych szczególnie że obiecują udostępniać coraz więcej metod pozwalających operować na zestawach dany sposób przewidywalny i na bez ale to są one całkowicie bezpieczne w niniejszym przykładzie pokażemy że zamykano z zasobów produkowanej przez strumienie jest subtelną różnicą którą ciężko wychwycić w programie stanu na którą trzeba zwrócić uwagę aby nie tracić zasobów

Dowód pierwszy: test na otwieranie zamykanie plików nie traci zasobów

Dowód drugi: test na otwieranie plików powoduje utraty zasobów jeżeli ich nie zamykamy

Dowód trzeci używanie strumieni w oparciu o pliki sposób podobny do używania strumienia partych o pamięć prowadzi do wycieku plików

Wnioski propozycje na przyszłość
