transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/JamesOh/Desktop/my\ EE\ Projects/ECE111/SHA-1 {C:/Users/JamesOh/Desktop/my EE Projects/ECE111/SHA-1/SHA1_hash.v}

