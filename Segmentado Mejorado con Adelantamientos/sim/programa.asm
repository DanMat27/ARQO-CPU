# Prog de prueba para Practica 2. Ej  1 y 2
# Daniel Mateo y Franccy del Piero Sambrano
# Grupo 1363

.data 0
num0: .word 1 # posic 0
num1: .word 2 # posic 4
num2: .word 4 # posic 8 
num3: .word 8 # posic 12 
num4: .word 16 # posic 16 
num5: .word 32 # posic 20
num6: .word 0 # posic 24
num7: .word 0 # posic 28
num8: .word 0 # posic 32
num9: .word 0 # posic 36
num10: .word 0 # posic 40
num11: .word 0 # posic 44

.text 0
main:
  # carga num0 a num5 en los registros 9 a 14
  lw $t1, 0($zero) # lw $r9, 0($r0)
  lw $t2, 4($zero) # lw $r10, 4($r0)
  lw $t3, 8($zero) # lw $r11, 8($r0)
  lw $t4, 12($zero) # lw $r12, 12($r0)
  lw $t5, 16($zero) # lw $r13, 16($r0)
  lw $t6, 20($zero) # lw $r14, 20($r0)
  nop
  nop
  nop
  nop
  # RIESGOS REGISTRO REGISTRO
  add $t3, $t1, $t2 # en r11 un 3 = 1 + 2
  beq $t3, $t3, salta1 # SALTO EFECTIVO CON R-TYPE ANTES
  add $t1, $t3, $t2 # dependencia con la anterior # No la hace
  nop
  nop
  nop
  salta1:
  add $t3, $t1, $t2 # en r11 un 3 = 1 + 2
  beq $t3, $t1, salta2 # SALTO NO EFECTIVO CON R-TYPE ANTES
  nop
  add $t2, $t4, $t3 #dependencia con la 2� anterior # en r10 un 11 = 8 + 3
  nop
  nop
  nop
  salta2:
  add $t3, $t1, $t2  # en r11 un 12 = 1 + 11 
  nop
  nop
  add $t2, $t3, $t5 #dependencia con la 3� anterior  # en r10 un 28 = 12 + 16
  nop
  nop
  nop
  add $s0, $t1, $t2  # en r16 un 29 = 1 + 28 
  add $s0, $s0, $s0  # Dependencia con la anterior  # en r16 un 58 = 29 + 29 
  add $s1, $s0, $s0  # dependencia con la anterior  # en r17 un 118 = 58 + 58 
  nop
  nop
  nop
  # RIESGOS REGISTRO MEMORIA
  add $t3, $t1, $t2 # en r11 un 29 = 1 + 28 
  sw $t3, 24($zero) # dependencia con la anterior # $24 = 29
  nop
  nop
  nop
  add $t4, $t1, $t2 # en r12 un 29 = 1 + 28
  nop
  sw $t4, 28($zero) # dependencia con la 2� anterior # $28 = 29
  nop
  nop
  nop
  add $t5, $t1, $t2 # en r13 un 29 = 1 + 28
  nop
  nop
  sw $t5, 32($zero) # dependencia con la 3� anterior # $32 = 29
  nop
  nop
  nop
  nop
  # RIESGOS MEMORIA REGISTRO
  lw $t3, 0($zero) # en r11 un 1
  beq $t3, $t3, salta3 # SALTO EFECTIVO CON LW ANTES
  add $t4, $t2, $t3 # dependencia con la anterior # No la hace
  nop
  nop
  nop
  salta3:
  lw $t3, 4($zero) # en r9 un 2
  beq $t3, $t4, salta4 # SALTO NO EFECTIVO CON LW ANTES
  nop
  add $t4, $t2, $t3 # dependencia con la 2� anterior # en r12 31 = 28 + 2
  nop
  nop
  salta4:
  lw $t3, 8($zero) # en r11 un 4
  nop
  nop
  add $t4, $t2, $t3 # dependencia con la 3� anterior # en r12 33 = 28 + 4
  nop
  nop
  nop
  # RIESGOS MEMORIA MEMORIA
  sw $t4, 0($zero) # $0 = 33
  lw $t2, 0($zero) # en r10 un 33
  nop
  nop
  nop
  nop
  lw $t2, 4($zero) # en r10 un 2
  sw $t2, 0($zero) # Guarda el 2 en posicion 0 de memoria # $0 = 2
  