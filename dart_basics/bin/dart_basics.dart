import 'dart:io';

void main(List<String> arguments) {
  
  print("Enter a number:");
  int number = int.parse(stdin.readLineSync()!);

  /*if (number < 0) {
    print("$number is negative.");
  } else if (number > 0) {
    print("$number is positive.");
  } else {
    print("$number is zero.");
  }*/

  switch (number) {
    case 1:
      print("$number es Enero.");
    case 2:
      print("$number es Febrero.");
    case 3:
      print("$number es Marzo.");
    case 4:     
      print("$number es Abril.");
    case 5:
      print("$number es Mayo.");
    case 6:
      print("$number es Junio.");
    case 7:
      print("$number es Julio.");
    case 8:
      print("$number es Agosto.");
    case 9:
      print("$number es Septiembre.");
    case 10:
      print("$number es Octubre.");
    case 11:
      print("$number es Noviembre.");
    case 12:
      print("$number es Diciembre.");
    default:
      print("Número no válido.");
  }
}

