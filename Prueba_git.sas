

%librerias(exadata=1);
%librerias(exadata=2);
%librerias(teradata=1);
%librerias(teradata=2);
%librerias(lap=1);
%librerias(lap=2);
%librerias(lac=1);
%librerias(lac=2);

Libname rrhh "/PF/JAMA2/fr_int";
Libname CTES_AV "/PF/JAMA2/Tablas";






***********************************************************************************************;
/*TRANSACCIONALIDAD*/
***********************************************************************************************;


%let mes_actual="01apr2020"d;







%LET N = 3; /*determinar el numero de particiones a buscar*/
DATA _NULL_;
	DO I = 1 TO &N;
		CALL SYMPUT('m'||LEFT(PUT(I, 3.)), PUT(INTNX('MONTH' , &mes_actual., -i+2, "BEGINNING"), yymmn4.)); /*loop para generar los nombres de las macros con formato aamm*/
	END;
RUN;
%put &m1. &m2. &m3. &mes_actual.; /*valido si se estan generando las macros*/






*==============================================================================================================;
/*	Movimientos de últimos 3 meses (incluye mes del alertamiento) [50 min]	*/
%macro movimientos_clientes2;
	%DO I = 1 %TO 3;

		PROC SQL;
			CONNECT TO ORACLE(&con_lap.);
			CREATE TABLE movtos_&&m&i. as 
				select 
					a.*,
					intnx('month', &mes_actual. , 1 - &i.) as mes_base_ format=date9.

				from connection to oracle(select /*+ parallel(10) */
												CD_CUENTA,
												NB_NO_MOV_CTA,
												case
								                    /*Pago Nomina*/
								                    when (NB_CONCEPTO like '%PAGO%NOMINA%' or NB_OBSERVACIONES like '%PAGO%NOMINA%') and NB_SIGNO = '+' then 'PAGA_NOMINA'
								                    when (NB_CONCEPTO like '%PAGO%NOMINA%' or NB_OBSERVACIONES like '%PAGO%NOMINA%') and NB_SIGNO = '-' then 'DISPERSA_NOMIMNA'
								                    /*RECIBE PORTABILIDAD*/
								                    when (NB_CONCEPTO like '%SPEI%RECIBIDO%' and NB_OBSERVACIONES like '%PORTABILIDAD%DE%NOMINA%') then 'PORTABILIDAD'
								                    /*Pago Cheques*/
								                    when (NB_CONCEPTO like '%CHEQUE%PAG%' or NB_OBSERVACIONES like '%CARGO%CHEQUE%') and NB_SIGNO = '+' then 'CHEQUE_COBRADO'
								                    when (NB_CONCEPTO like '%CHEQUE%PAG%' or NB_OBSERVACIONES like '%CARGO%CHEQUE%') and NB_SIGNO = '-' then 'CHEQUE_EMITIDO'
								                    /*Retiro Cajero*/
								                    when (NB_CONCEPTO like '%RETIRO%CAJ%') and NB_SIGNO = '+' then 'DEPOSITO_CAJERO'
								                    when (NB_CONCEPTO like '%RETIRO%CAJ%') and NB_SIGNO = '-' then 'RETIRO_CAJERO'
								                    /*Retiro Cajero (Otro banco)*/
								                    when (NB_CONCEPTO like '%RET%CAJ%OT%') and NB_SIGNO = '+' then 'DEPOSITO_CAJERO_OTRO_BANCO'
								                    when (NB_CONCEPTO like '%RET%CAJ%OT%') and NB_SIGNO = '-' then 'RETIRO_CAJERO_OTRO_BANCO'
								                    /*Spei enviado*/
								                    when (NB_CONCEPTO like '%SPEI%ENV%') then 'SPEI_ENVIADO'
								                    when (NB_CONCEPTO like '%SPEI%RECIBIDO%' and NB_OBSERVACIONES not like '%PORTABILIDAD%DE%NOMINA%') then 'SPEI_RECIBIDO'
								                    /*TEF enviado*/
								                    when (NB_CONCEPTO like '%TEF%ENVIADO%') then 'TEF_ENVIADO'
								                    when (NB_CONCEPTO like '%TEF%RECIB%') then 'TEF_RECIBIDO'
								                    /*Retiro en ventanilla*/
								                    when (NB_CONCEPTO like '%RETIRO%EN%VE%') and NB_SIGNO = '+' then 'DEPOSITO_VENTANILLA'
								                    when (NB_CONCEPTO like '%SU%PAGO%EN%EFECTIVO%') and NB_SIGNO = '+' then 'DEPOSITO_VENTANILLA'
								                    when (NB_CONCEPTO like '%DEPOSITO%EN%EFECTIVO%') and NB_SIGNO = '+' then 'DEPOSITO_VENTANILLA'            
								                    when (NB_CONCEPTO like '%RETIRO%EN%VE%') and NB_SIGNO = '-' then 'RETIRO_VENTANILLA'
								                    when (NB_CONCEPTO like '%DEPOSITO%EN%EFECTIVO%') and NB_SIGNO = '-' then 'RETIRO_VENTANILLA'   
								                    /*Cuenta terceros*/
								                    when (NB_CONCEPTO like '%PAGO%CUENTA%DE%TER%') and NB_SIGNO = '+' then 'DEPOSITO_CTA_TERCERO'
								                    when (NB_CONCEPTO like '%PAGO%CUENTA%DE%TER%') and NB_SIGNO = '-' then 'ENVIO_CTA_TERCERO'
								                    /*Retiro sin tarjeta*/
								                    when (NB_CONCEPTO like '%RETIRO%SIN%TARJETA%') then 'RETIRO_SIN_TARJETA'
								                    /*PRESTAMO*/
								                    when (NB_CONCEPTO like '%COBRO%AUTOMATICO%RECIBO%') then 'PAGO_PRESTAMO'
								                    when (NB_CONCEPTO like '%DEPOSITO%PRESTAMO%') then 'OTORGA_PRESTAMO'
								                    
								                    /*PRACTICAJAS*/
								                    when (NB_CONCEPTO like '%DEPOSITO%EFECTIVO%PRACTIC%') then 'DEPOSITO_PRACTICAJA'
													else 'n/a'
								                end as TPO_MOV,
												NB_SIGNO,
												case
													when ((NB_CONCEPTO like '%PAGO%NOMINA%' or NB_OBSERVACIONES like '%PAGO%NOMINA%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%SPEI%RECIBIDO%' and NB_OBSERVACIONES like '%PORTABILIDAD%DE%NOMINA%')) then '_ingreso_'
													when ((NB_CONCEPTO like '%CHEQUE%PAG%' or NB_OBSERVACIONES like '%CARGO%CHEQUE%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%RETIRO%CAJ%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%RET%CAJ%OT%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%SPEI%RECIBIDO%' and NB_OBSERVACIONES not like '%PORTABILIDAD%DE%NOMINA%')) then '_ingreso_'
													when ((NB_CONCEPTO like '%TEF%RECIB%')) then '_ingreso_'
													when ((NB_CONCEPTO like '%RETIRO%EN%VE%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%SU%PAGO%EN%EFECTIVO%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%DEPOSITO%EN%EFECTIVO%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%PAGO%CUENTA%DE%TER%') and NB_SIGNO = '+') then '_ingreso_'
													when ((NB_CONCEPTO like '%DEPOSITO%PRESTAMO%')) then '_ingreso_'
													when ((NB_CONCEPTO like '%DEPOSITO%EFECTIVO%PRACTIC%')) then '_ingreso_'
													when ((NB_CONCEPTO like '%CHEQUE%PAG%' or NB_OBSERVACIONES like '%CARGO%CHEQUE%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%RETIRO%CAJ%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%PAGO%CUENTA%DE%TER%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%SPEI%ENV%')) then '_egreso_'
													when ((NB_CONCEPTO like '%RETIRO%SIN%TARJETA%' and NB_SIGNO = '-')) then '_egreso_'
													when ((NB_CONCEPTO like '%COBRO%AUTOMATICO%RECIBO%')) then '_egreso_'
													when ((NB_CONCEPTO like '%RET%CAJ%OT%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%RETIRO%EN%VE%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%DEPOSITO%EN%EFECTIVO%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%PAGO%NOMINA%' or NB_OBSERVACIONES like '%PAGO%NOMINA%') and NB_SIGNO = '-') then '_egreso_'
													when ((NB_CONCEPTO like '%TEF%ENVIADO%')) then '_egreso_'
													else 'n/a'
												end as tp_mov_cte,
												IM_IMPORTE/100 "IM_IMPORTE"

											from GORAPR.TLP122_MOVTOS partition(P&&m&i.)
											where ((CD_CUENTA in ('0100061484') and NB_PERSONA='F') and (
															NB_CONCEPTO like '%PAGO%NOMINA%' or  
															NB_CONCEPTO like '%SPEI%RECIBIDO%' or  
															NB_CONCEPTO like '%CHEQUE%PAG%' or  
															NB_CONCEPTO like '%RETIRO%CAJ%' or  
															NB_CONCEPTO like '%RET%CAJ%OT%' or  
															NB_CONCEPTO like '%SPEI%ENV%' or  
															NB_CONCEPTO like '%TEF%ENVIADO%' or  
															NB_CONCEPTO like '%TEF%RECIB%' or  
															NB_CONCEPTO like '%RETIRO%EN%VE%' or  
															NB_CONCEPTO like '%SU%PAGO%EN%EFECTIVO%' or  
															NB_CONCEPTO like '%DEPOSITO%EN%EFECTIVO%' or  
															NB_CONCEPTO like '%PAGO%CUENTA%DE%TER%' or  
															NB_CONCEPTO like '%RETIRO%SIN%TARJETA%' or  
															NB_CONCEPTO like '%COBRO%AUTOMATICO%RECIBO%' or  
															NB_CONCEPTO like '%DEPOSITO%PRESTAMO%' or  
															NB_CONCEPTO like '%DEPOSITO%EFECTIVO%PRACTIC%' or 
															NB_OBSERVACIONES like '%PAGO%NOMINA%' or 
															NB_OBSERVACIONES like '%CARGO%CHEQUE%' or 
															NB_OBSERVACIONES like '%PORTABILIDAD%DE%NOMINA%')
														)
										) as a
			;
			disconnect from oracle;
		QUIT;

		%if &i. eq 1 %then
			%do;

				data work.historia;
					set work.movtos_&&m&i.;
				run;

			%end;
		%else
			%do;

				proc append base=work.historia data=work.movtos_&&m&i.;
				run;

			%end;

		PROC SQL;
			DROP TABLE work.movtos_&&m&i.;
		QUIT;

		



	%END;
/*
	Proc sql;
		create table historia as 
			select
				a.CD_CUENTA,
				a.TP_MOV_CTE,
				sum(IM_IMPORTE) as SUM_IMPORTE format=dollar25.2,
				count(*) as NO_REGS 

		from historia as a
		group by a.CD_CUENTA, a.TP_MOV_CTE	;
	quit;

	proc transpose data = historia out=historia;
		by CD_CUENTA;
		id TP_MOV_CTE;
		var SUM_IMPORTE;
	run;

	Proc sql;
		create table historia as 
			select
				a.CD_CUENTA,
				a._egreso_,
				a._ingreso_,
				round(a._egreso_/a._ingreso_,.01) as pct_maldad format=percent10.1,
				case
					when a._egreso_/a._ingreso_ between 0.85 and 1.15 then 'Anormal'
					else 'Normal'
				end as Ratio_
				

		from historia as a
	;
	quit;*/
%mend movimientos_clientes2;
%movimientos_clientes2;


