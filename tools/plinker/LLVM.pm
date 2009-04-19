#
#  Perl code for generating LLVM assembly from ETC assembly
#  Copyright (C) 2009 Carl Ritson <cgr@kent.ac.uk>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#

package Transputer::LLVM;

use strict;
use vars qw($GRAPH);
use Data::Dumper;

$GRAPH = {
	# Branching
	'CALL'		=> { 'branching' => 1, 'in' => 3, 'out' => 0, 
			'generator' => \&gen_call }, # actually out is 3
	'CJ'		=> { 'branching' => 1, 'in' => 3, 'out' => 2,
			'generator' => \&gen_cj },
	'GCALL'		=> { 'branching' => 1, 'in' => 3,
			'generator' => \&gen_call }, # check
	'J' 		=> { 'branching' => 1, 'in' => 3,
			'generator' => \&gen_j },
	'LEND'		=> { 'branching' => 1, 'in' => 1,
			'generator' => \&gen_lend },
	'LEND3'		=> { 'branching' => 1, 'in' => 1,
			'generator' => \&gen_lend },
	'LENDB'		=> { 'branching' => 1, 'in' => 1,
			'generator' => \&gen_lend },
	'RET'		=> { # Intentionally not 'branching' => 1,
			'generator' => \&gen_ret },
	'TABLE'		=> { 'branching' => 1, 'in' => 1,
			'generator' => \&gen_table },
	# Workspace/Operand Stack
	'AJW'		=> { 'wptr' => 1, 
			'generator' => \&gen_ajw },
	'REV'		=> { 'in' => 2, 'out' => 2,
			'generator' => \&gen_rev },
	'POP'		=> { 'in' => 1,
			'generator' => \&gen_nop },
	'GAJW'		=> { 'in' => 1, 'out' => 1, 'wptr' => 1,
			'generator' => \&gen_gajw },
	'DUP'		=> { 'in' => 1, 'out' => 2, 
			'generator' => \&gen_dup },
	# Load/Store
	'LDLP'		=> { 'out' => 1, 
			'generator' => \&gen_ldlp },
	'LDNL'		=> { 'in' => 1, 'out' => 1, 
			'generator' => \&gen_ldnl },
	'LDNLP'		=> { 'in' => 1, 'out' => 1, 
			'generator' => \&gen_ldnlp },
	'LDL'		=> { 'out' => 1, 
			'generator' => \&gen_ldl },
	'STL'		=> { 'in' => 1, 
			'generator' => \&gen_stl },
	'STNL'		=> { 'in' => 2, 
			'generator' => \&gen_stnl },
	'LB'		=> { 'in' => 1, 'out' => 1,
			'generator' => \&gen_lb },
	'BSUB'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_bsub },
	'LDPI'		=> { 
			'generator' => \&gen_nop },
	'WSUB'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_wsub },
	'WSUBDB'	=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_wsub },
	'CSUB0'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_csub0 },
	'MOVE'		=> { 'in' => 3 },
	# Constants
	'LDC'		=> { 'out' => 1, 
			'generator' => \&gen_ldc },
	'LDINF'		=> { 'out' => 1,
			'generator' => \&gen_ldinf },
	'NULL'		=> { 'out' => 1,
			'generator' => \&gen_null },
	'MINT'		=> { 'out' => 1,
			'generator' => \&gen_mint },
	# Arithmetic
	'ADC'		=> { 'in' => 1, 'out' => 1, 
			'generator' => \&gen_adc },
	'EQC'		=> { 'in' => 1, 'out' => 1,
			'generator' => \&gen_eqc },
	'DIFF'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_diff },
	'ADD'		=> { 'in' => 2, 'out' => 1, 
			'generator' => \&gen_add },
	'PROD'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_prod },
	'GT'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_gt },
	'SUB'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_sub },
	'REM'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_divrem },
	'DIV'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_divrem },
	'NOT'		=> { 'in' => 1, 'out' => 1,
			'generator' => \&gen_not },
	'XOR'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_xor },
	'SB'		=> { 'in' => 2,
			'generator' => \&gen_sb },
	'SHR'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_shr },
	'SHL'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_shl },
	'AND'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_and },
	'OR'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_or },
	'SUM'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_sum },
	'MUL'		=> { 'in' => 2, 'out' => 1,
			'generator' => \&gen_mul },
	'BOOLINVERT'	=> { 'in' => 1, 'out' => 1,
			'generator' => \&gen_boolinvert },
	'NORM'		=> { 'in' => 3, 'out' => 3 },
	'POSTNORMSN'	=> { 'in' => 3, 'out' => 3 },
	'ROUNDSN'	=> { 'in' => 3, 'out' => 1 },
	# Long Arithmetic
	'XDBLE'		=> { 'in' => 1, 'out' => 2 },
	'LADD'		=> { 'in' => 3, 'out' => 1 },
	'LDIFF'		=> { 'in' => 3, 'out' => 2 },
	'LDIV'		=> { 'in' => 3, 'out' => 2 },
	'LMUL'		=> { 'in' => 3, 'out' => 2 },
	'LSHR'		=> { 'in' => 3, 'out' => 2 },
	'LSHL'		=> { 'in' => 3, 'out' => 2 },
	'LSUM'		=> { 'in' => 3, 'out' => 2 },
	'LSUB'		=> { 'in' => 3, 'out' => 2 },
	# Errors
	'SETERR'	=> {
			'generator' => \&gen_seterr },
	'FPCHKERR'	=> { },
	# Floating Point
	'FPLDNLDBI'	=> { 'in' => 2, 'fout' => 1 },
	'FPSTNLDB'	=> { 'in' => 1, 'fin' => 1 },
	'FPLDNLSNI'	=> { 'in' => 2, 'fout' => 1 },
	'FPADD'		=> { 'fin' => 2, 'fout' => 1 },
	'FPSTNLSN'	=> { 'in' => 1, 'fin' => 1 },
	'FPSUB'		=> { 'fin' => 2, 'fout' => 1 },
	'FPLDNLDB'	=> { 'in' => 1, 'fout' => 1 },
	'FPMUL'		=> { 'fin' => 2, 'fout' => 1 },
	'FPDIV'		=> { 'fin' => 2, 'fout' => 1 },
	'FPLDNLSN'	=> { 'in' => 1, 'fout' => 1 },
	'FPNAN'		=> { 'fin' => 1, 'fout' => 1, 'out' => 1 },
	'FPORDERED'	=> { 'fin' => 2, 'fout' => 2, 'out' => 1 },
	'FPNOTFINITE'	=> { 'fin' => 1, 'fout' => 1, 'out' => 1 },
	'FPGT'		=> { 'fin' => 2, 'out' => 1 },
	'FPEQ'		=> { 'fin' => 2, 'out' => 1 },
	'FPI32TOR32'	=> { 'in' => 1, 'fout' => 1 },
	'FPI32TOR64'	=> { 'in' => 1, 'fout' => 1 },
	'FPB32TOR64'	=> { 'in' => 1, 'fout' => 1 },
	'FPRTOI32'	=> { 'fin' => 1, 'fout' => 1 },
	'FPSTNLI32'	=> { 'in' => 1, 'fin' => 1 },
	'FPLDZEROSN'	=> { 'fout' => 1 },
	'FPLDZERODB'	=> { 'fout' => 1 },
	'FPINT'		=> { 'fin' => 1, 'fout' => 1 },
	'FPDUP'		=> { 'fin' => 1, 'fout' => 2 },
	'FPREV'		=> { 'fin' => 2, 'fout' => 2 },
	'FPLDNLADDDB'	=> { 'in' => 1, 'fin' => 1, 'fout' => 1 },
	'FPLDNLMULDB'	=> { 'in' => 1, 'fin' => 1, 'fout' => 1 },
	'FPLDNLADDSN'	=> { 'in' => 1, 'fin' => 1, 'fout' => 1 },
	'FPLDNLMULSN'	=> { 'in' => 1, 'fin' => 1, 'fout' => 1 },
	'FPREM'		=> { 'fin' => 2, 'fout' => 1 },
	'FPDIVBY2'	=> { 'fin' => 1, 'fout' => 1 },
	'FPMULBY2'	=> { 'fin' => 1, 'fout' => 1 },
	'FPSQRT'	=> { 'fin' => 1, 'fout' => 1 },
	'FPRZ'		=> { },
	'FPR32TOR64'	=> { 'fin' => 1, 'fout' => 1 },
	'FPR64TOR32'	=> { 'fin' => 1, 'fout' => 1 },
	'FPEXPDEC32'	=> { 'fin' => 1, 'fout' => 1 },
	'FPABS'		=> { 'fin' => 1, 'fout' => 1 },
	# Kernel
	'ENDP'		=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_endp' },
	'IN'		=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'Y_in' },
	'OUT'		=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'Y_out' },
	'STARTP'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_startp' },
	'OUTBYTE'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_outbyte' },
	'OUTWORD'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_outword' },
	'MRELEASEP'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_mreleasep' },
	'RUNP'		=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'X_runp' },
	'STOPP'		=> { 'kcall' => 1,
		'symbol' => 'Y_stopp' },
	'LDTIMER'	=> { 'kcall' => 1, 'out' => 1,
		'symbol' => 'X_ldtimer' },
	'TIN'		=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_tin' },
	'MALLOC'	=> { 'kcall' => 1, 'in' => 1, 'out' => 1,
		'symbol' => 'X_malloc' },
	'MRELEASE'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'X_mrelease' },
	'XABLE'		=> { 'kcall' => 1,
		'symbol' => 'Y_xable' },
	'XIN'		=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'Y_xin' },
	'XEND'		=> { 'kcall' => 1,
		'symbol' => 'Y_xend' },
	'PROC_ALLOC'	=> { 'kcall' => 1, 'in' => 2, 'out' => 1,
		'symbol' => 'X_proc_alloc' },
	'PROC_PARAM'	=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'X_proc_param' },
	'PROC_MT_COPY'	=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'X_proc_mt_copy' },
	'PROC_MT_MOVE'	=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'X_proc_mt_move' },
	'PROC_START'	=> { 'kcall' => 1, 'in' => 3,
		'symbol' => 'Y_proc_start' },
	'PROC_END'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_proc_end' },
	'GETAFF'	=> { 'kcall' => 1, 'out' => 1,
		'symbol' => 'X_getaff' },
	'SETAFF'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_setaff' },
	'GETPAS'	=> { 'kcall' => 1, 'out' => 1, 
		'symbol' => 'X_getpas' },
	'GETPRI'	=> { 'kcall' => 1, 'out' => 1,
		'symbol' => 'X_getpri' },
	'SETPRI'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_setpri' },
	'MT_ALLOC'	=> { 'kcall' => 1, 'in' => 2, 'out' => 1,
		'symbol' => 'X_mt_alloc' },
	'MT_RELEASE'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'X_mt_release' },
	'MT_CLONE'	=> { 'kcall' => 1, 'in' => 1, 'out' => 1,
		'symbol' => 'X_mt_clone' },
	'MT_IN'		=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_in' },
	'MT_OUT'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_out' },
	'MT_XCHG'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_xchg' },
	'MT_LOCK'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_lock' },
	'MT_UNLOCK'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'X_mt_unlock' },
	'MT_ENROLL'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'X_mt_enroll' },
	'MT_RESIGN'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'X_mt_resign' },
	'MT_SYNC'	=> { 'kcall' => 1, 'in' => 1,
		'symbol' => 'Y_mt_sync' },
	'MT_XIN'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_xin' },
	'MT_XOUT'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_xout' },
	'MT_XXCHG'	=> { 'kcall' => 1, 'in' => 2,
		'symbol' => 'Y_mt_xxchg' },
	'MT_DCLONE'	=> { 'kcall' => 1, 'in' => 3, 'out' => 1,
		'symbol' => 'X_mt_dclone' },
	'MT_BIND'	=> { 'kcall' => 1, 'in' => 3, 'out' => 1,
		'symbol' => 'X_mt_bind' },
	'MT_RESIZE'	=> { 'kcall' => 1, 'in' => 3, 'out' => 1,
		'symbol' => 'X_mt_resize' },
	# ALTing
	'ALT'		=> { 'kcall' => 1, 
		'symbol' => 'X_alt' },
	'TALT'		=> { 'kcall' => 1, 
		'symbol' => 'X_talt' },
	'ALTWT'		=> { 'kcall' => 1, 
		'symbol' => 'Y_altwt' },
	'TALTWT'	=> { 'kcall' => 1, 
		'symbol' => 'Y_taltwt' },
	'ALTEND'	=> { 'kcall' => 1, 
		'symbol' => 'Y_altend' },
	'ENBT'		=> { 'kcall' => 1, 'in' => 2, 'out' => 1 },
	'ENBT3'		=> { 'kcall' => 1, 'in' => 3, 'out' => 1 },
	'ENBC'		=> { 'kcall' => 1, 'in' => 2, 'out' => 1 },
	'ENBC3'		=> { 'kcall' => 1, 'in' => 3, 'out' => 1 },
	'ENBS'		=> { 'kcall' => 1, 'in' => 1, 'out' => 1 },
	'ENBS3'		=> { 'kcall' => 1, 'in' => 2, 'out' => 1 },
	'DISC'		=> { 'kcall' => 1, 'in' => 3, 'out' => 1 },
	'DIST'		=> { 'kcall' => 1, 'in' => 3, 'out' => 1 },
	'DISS'		=> { 'kcall' => 1, 'in' => 2, 'out' => 1 },
	# External Channels
	'EXTVRFY' 	=> { 'kcall' => 1, 'in' => 2 },
	'EXTIN'		=> { 'kcall' => 1, 'in' => 3 },
	'EXTOUT'	=> { 'kcall' => 1, 'in' => 3 },
	'EXT_MT_IN'	=> { 'kcall' => 1, 'in' => 2 },
	'EXT_MT_OUT'	=> { 'kcall' => 1, 'in' => 2 },
};


sub new ($$) {
	my ($class) = @_;
	my $self = bless {}, $class;
	$self->{'constants'}	= {};
	$self->{'globals'}	= {};
	$self->{'source_files'}	= {};
	$self->{'source_file'}	= undef;
	$self->{'source_line'} 	= 0;
	$self->{'header'}	= {};
	return $self;
}

sub message ($$$) {
	my ($self, $warning, $msg) = @_;
	my $file = $self->{'constants'}->{$self->source_file}->{'str'};
	my $line = $self->source_line;

	if ($warning) {
		print STDERR "$file:$line $msg\n";
	} else {
		print "$file:$line $msg\n";
	}
}

sub foreach_label ($$@) {
	my ($labels, $func, @param) = @_;
	my @labels = keys (%$labels);
	foreach my $label (@labels) {
		&$func ($labels, $labels->{$label}, @param);
	}
}

sub foreach_inst ($$$@) {
	my ($labels, $label, $func, @param) = @_;
	my $inst = $label->{'inst'};
	foreach my $inst (@$inst) {
		&$func ($labels, $label, $inst, @param);
	}
}

sub resolve_inst_label ($$$$) {
	my ($labels, $label, $inst, $fn) = @_;
	
	return if $inst->{'name'} =~ /^\..*BYTES$/;
	
	my $arg = $inst->{'arg'};
	foreach my $arg (ref ($arg) =~ /^ARRAY/ ? @$arg : $arg) {
		if ($arg =~ /^L([0-9_\.]+)$/) {
			my $num	= $1;
			my $n	= 'L' . $fn . '.' . $num;
			if (!exists ($labels->{$n})) {
				die "Undefined label $n";
			} else {
				if ($arg eq $inst->{'arg'}) {
					$inst->{'arg'} = $labels->{$n};
				} else {
					$arg = $labels->{$n};
				}
				$labels->{$n}->{'refs'}++;
			}
			$inst->{'label_arg'} = 1;
		}
	}
}

sub resolve_labels ($$$) {
	my ($labels, $label, $fn) = @_;
	foreach_inst ($labels, $label, \&resolve_inst_label, $fn);
}

sub resolve_inst_globals ($$$$$) {
	my ($labels, $label, $inst, $globals, $ffi) = @_;
	if ($inst->{'label_arg'}) {
		my $arg = $inst->{'arg'};
		if ((ref ($arg) =~ /^HASH/) && $arg->{'stub'}) {
			my $n = $arg->{'stub'};
			if (exists ($globals->{$n})) {
				$inst->{'arg'} = $globals->{$n};
				$globals->{$n}->{'refs'}++;
			} elsif (exists ($ffi->{$n})) {
				$inst->{'arg'} = $ffi->{$n};
				$ffi->{$n}->{'refs'}++;
			} else {
				#die "Undefined global reference $n";
			}
		}
	}
}

sub resolve_globals ($$$$) {
	my ($labels, $label, $globals, $ffi) = @_;
	foreach_inst ($labels, $label, \&resolve_inst_globals, $globals, $ffi);
}

sub build_data_blocks ($$) {
	my ($labels, $label) = @_;
	my ($data, $inst) = (undef, 0);
	foreach my $op (@{$label->{'inst'}}) {
		my $name = $op->{'name'};
		if ($name =~ /^[^\.]/) {
			$inst++;
		} elsif ($name eq '.DATABYTES') {
			$data .= $op->{'arg'};
			$op->{'bytes'}	= [ split (//, $op->{'arg'}) ];
			$op->{'length'}	= length ($op->{'arg'});
		}
	}
	if (!$inst && $data) {
		$label->{'data'} = $data;
		if ($label->{'prev'}) {
			$label->{'prev'}->{'next'} = $label->{'next'};
		}
		if ($label->{'next'}) {
			$label->{'next'}->{'prev'} = $label->{'prev'};
		}
		delete ($label->{'prev'});
		delete ($label->{'next'});
	}
}

sub add_data_lengths ($$) {
	my ($labels, $label) = @_;
	if ($label->{'data'}) {
		$label->{'length'} = length ($label->{'data'});
	}
}

sub new_sub_label ($$$$) {
	my ($labels, $label, $current, $sub_idx) = @_;
	my $name		= sprintf ('%s_%d', $label->{'name'}, ($$sub_idx)++);
	my $new 		= {
		'name' => $name, 
		'prev' => $current,
		'next' => $current->{'next'},
		'inst' => undef
	};
	$current->{'next'}	= $new;
	if ($new->{'next'}) {
		$new->{'next'}->{'prev'} = $new;
	}
	$labels->{$name}	= $new;
	return $new;
}

sub isolate_branches ($$) {
	my ($labels, $label) = @_;
	
	return if $label->{'data'};

	my @inst	= @{$label->{'inst'}};
	my $sub_idx	= 0;
	my $current	= $label;
	my $cinst	= [];
	for (my $i = 0; $i < @inst; ++$i) {
		my $inst = $inst[$i];
		my $data = $GRAPH->{$inst->{'name'}};
		if ($data && ($data->{'branching'} || $data->{'kcall'})) {
			if (@$cinst > 0) {
				$current->{'inst'}	= $cinst;
				$current		= new_sub_label (
					$labels, $label, $current, \$sub_idx
				);
				$cinst			= [];
			}
			$current->{'inst'}		= [ $inst ];
			$current 			= new_sub_label (
				$labels, $label, $current, \$sub_idx
			) if $i < (@inst - 1);
		} else {
			push (@$cinst, $inst);
		}
	}
	if (@$cinst > 0) {
		$current->{'inst'} = $cinst;
	}
}

sub tag_and_index_code_blocks ($) {
	my ($procs) = @_;
	foreach my $proc (@$procs) {
		my @labels	= ($proc);
		my $label	= $proc->{'next'};
		my $idx		= 0;
		$proc->{'proc'}	= $proc;
		$proc->{'idx'}	= $idx++;
		while ($label && !$label->{'symbol'}) {
			$label->{'proc'}	= $proc;
			$label->{'idx'}		= $idx++;
			push (@labels, $label);
			$label = $label->{'next'};
		}
		$proc->{'labels'} = \@labels;
	}
}

sub separate_code_blocks ($) {
	my ($procs) = @_;
	foreach my $proc (@$procs) {
		my $labels	= $proc->{'labels'};
		my $first	= $proc;
		my $last	= $labels->[-1];

		if ($first->{'prev'}) {
			delete ($first->{'prev'}->{'next'});
		}
		delete ($first->{'prev'});

		if ($last->{'next'}) {
			delete ($last->{'next'}->{'prev'});
		}
		delete ($last->{'next'});
	}
}

sub instruction_proc_dependencies ($$$$) {
	my (undef, $label, $inst, $depends) = @_;
	if ($inst->{'label_arg'}) {
		my $arg = $inst->{'arg'};
		foreach my $arg (ref ($arg) =~ /^ARRAY/ ? @$arg : $arg) {
			next if !ref ($arg);
			if ($label->{'proc'} ne $arg->{'proc'}) {
				$depends->{$arg} = $arg;
			}
		}
	}
}

sub expand_etc_ops ($) {
	my ($etc) = @_;
	my %IGNORE_SPECIAL = (
		'CONTRJOIN'	=> 1,
		'CONTRSPLIT'	=> 1,
		'FPPOP'		=> 1
	);
	my ($labn, $labo) = (0, 0);
	
	for (my $i = 0; $i < @$etc; ++$i) {
		my $op		= $etc->[$i];
		my $name	= $op->{'name'};
		my $arg		= $op->{'arg'};
		if ($name =~ /^\.(SET|SECTION)LAB$/) {
			$labn = $arg;
			$labo = 0;
		} elsif ($name eq '.LABEL') {
			if (ref ($arg) =~ /^ARRAY/) {
				my $l1 = $arg->[0];
				my $l2 = $arg->[1];
				if ($l2->{'arg'} >= 0) {
					$l1->{'arg'}	= [ $l1->{'arg'}, 'L' . $l2->{'arg'} ];
					$etc->[$i]	= $l1;
				} else {
					#$l1->{'arg'} 	= [ $l1->{'arg'}, 'LDPI' ];
					#splice (@$etc, $i, 1, 
					#	$l1,
					#	{ 'name' => 'LDPI' }
					#);
					splice (@$etc, $i, 1, $l1);
				}
			} else {
				$etc->[$i] = $arg;
			}
		} elsif ($name eq '.SPECIAL') {
			my $name	= $arg->{'name'};

			if ($name eq 'NOTPROCESS') {
				$op = { 
					'name'	=> 'LDC',
					'arg'	=> 0
				};
			} elsif ($name eq 'STARTTABLE') {
				my (@arg, $done, @table);
				for (my $j = ($i+1); !$done && $j < @$etc; ++$j) {
					my $op = $etc->[$j];
					if ($op->{'name'} eq '.LABEL') {
						my $op = $op->{'arg'};
						if ($op->{'name'} eq 'J') {
							push (@arg, $op->{'arg'});
							push (@table, $op);
							next;
						}
					}
					$done = 1;
				}
				$op->{'name'}		= 'TABLE';
				$op->{'arg'}		= \@arg;
				$op->{'label_arg'}	= 1;
				$op->{'table'}		= \@table;
				splice (@$etc, $i, @arg + 1,
					$op
				);
			} elsif (!exists ($IGNORE_SPECIAL{$name})) {
				$op = $arg;
			}
			
			$etc->[$i] = $op;
		} elsif ($name =~ /^\.(LEND.?)$/) {
			my $name	= $1;
			my @arg		= @$arg;
			my $start	= ($arg[2] =~ /^L(\d+)$/)[0];
			my $end		= ($arg[1] =~ /^L(\d+)$/)[0];
			splice (@$etc, $i, 1, 
				$arg[0],
				{ 'name' => $name, 'arg' => "L$start"			},
				{ 'name' => '.SETLAB', 'arg' => $end			}
			);
		} elsif ($name =~ /^\.SL([RL])IMM$/) {
			$op->{'name'} = "SH$1";
		}
	}
}

sub preprocess_etc ($$$) {
	my ($self, $file, $etc) = @_;
	my ($current, %labels, @procs);
	my $globals	= $self->{'globals'};
	
	my $fn		= 0;
	my $align	= 0;
	my $filename	= undef;
	my $line	= undef;

	# Initial operation translation
	expand_etc_ops ($etc);

	# Build ETC stream for each label
	# Identify PROCs and global symbols
	# Carry alignment
	# Carry file names and line numbers
	foreach my $op (@$etc) {
		my $name	= $op->{'name'};
		my $arg		= $op->{'arg'};

		if ($name eq '.ALIGN') {
			$align	= $arg;
		} elsif ($name =~ /^\.(SET|SECTION)LAB$/) {
			my $label = 'L' . $fn . '.' . $arg;
			my @inst;

			die "Label collision $label" 
				if exists ($labels{$label});
			
			if ($filename) {
				push (@inst, { 
					'name'	=> '.FILENAME',
					'arg'	=> $filename
				});
			}
			if (defined ($line)) {
				push (@inst, {
					'name'	=> '.LINE',
					'arg'	=> $line
				});
			}
			if ($align) {
				push (@inst, {
					'name'	=> '.ALIGN',
					'arg'	=> $align
				});
			}

			my $new = { 
				'name'		=> $label, 
				'prev'		=> $current, 
				'inst'		=> \@inst,
				'align'		=> $align,
				'source'	=> $etc
			};

			$current->{'next'} 	= $new;
			$current 		= $new;
			$labels{$label}		= $new;

			$align			= 0;
		} elsif ($name eq '.FILENAME') {
			$filename		= $arg;
		} elsif ($name eq '.LINE') {
			$line			= $arg;
		} elsif ($name eq '.PROC') {
			$current->{'symbol'}	= $arg;
			push (@procs, $current);
		} elsif ($name eq '.STUBNAME') {
			$current->{'stub'}	= $arg;
			$current->{'symbol'}	= $arg;
			#if ($arg =~ /^(C|BX?)\./) {
			#	$ffi{$arg} = $current
			#		if !exists ($ffi{$arg});
			#}
		} elsif ($name eq '.GLOBAL') {
			if (exists ($globals->{$arg})) {
				my $current 	= $globals->{$arg};
				my $c_file	= $current->{'loci'}->{'file'};
				my $c_fn	= $current->{'loci'}->{'filename'};
				my $c_ln	= $current->{'loci'}->{'line'};
				print STDERR 
					"Warning: multiple definitions of global name '$arg'\n",
					"\tOld symbol is from $c_fn($c_file), line $c_ln.";
					"\tNew symbol is from $filename($file), line $line.";
			}
			$globals->{$arg}	= $current;
			$current->{'loci'}	= {
				'file'		=> $file,
				'filename'	=> $filename,
				'line'		=> $line
			};
		} elsif ($name eq '.GLOBALEND') {
			$globals->{$arg}->{'end'} = $current;
		}
		
		push (@{$current->{'inst'}}, $op)
			if $current; 
	}

	$self->{'file'}		= $file;
	$self->{'filename'}	= $filename;
	$self->{'labels'}	= \%labels;
	$self->{'procs'}	= \@procs;

	foreach_label (\%labels, \&resolve_labels, 0);
	foreach_label (\%labels, \&resolve_globals, $globals, {});
	foreach_label (\%labels, \&build_data_blocks);
	foreach_label (\%labels, \&add_data_lengths);
	foreach_label (\%labels, \&isolate_branches);
	tag_and_index_code_blocks (\@procs);
	separate_code_blocks (\@procs);
}

sub define_registers ($$) {
	my ($self, $labels) = @_;
	my ($reg_n, $freg_n, $wptr_n) 	= (0, 0, 0);
	my $wptr			= sprintf ('wptr_%d', $wptr_n++);
	my (@stack, @fstack);

	foreach my $label (@$labels) {
		#print $label->{'name'}, " ", join (', ', @stack, @fstack), " ($wptr)\n";
		
		$label->{'in'} = [ @stack ];
		$label->{'fin'} = [ @fstack ];
		$label->{'wptr'} = $wptr;

		foreach my $inst (@{$label->{'inst'}}) {
			my $name = $inst->{'name'};
			next if $name =~ /^\./;
			my (@in, @out, @fin, @fout);
			my $data	= $GRAPH->{$name};
			for (my $i = 0; $i < $data->{'in'}; ++$i) {
				my $reg = shift (@stack);
				push (@in, $reg) if $reg;
			}
			my $out = $data->{'out'};
			if ($name eq 'CJ') {
				$out = @in - ($data->{'in'} - $out);
			}
			for (my $i = 0; $i < $out; ++$i) {
				my $reg = sprintf ('reg_%d', $reg_n++);
				unshift (@out, $reg);
				unshift (@stack, $reg);
			}
			for (my $i = 0; $i < $data->{'fin'}; ++$i) {
				my $reg = shift (@fstack) || 'null';
				unshift (@in, $reg);
			}
			for (my $i = 0; $i < $data->{'fout'}; ++$i) {
				my $reg = sprintf ('freg_%d', $freg_n++);
				unshift (@out, $reg);
				unshift (@stack, $reg);
			}
			$inst->{'in'} = \@in if @in;
			$inst->{'out'} = \@out if @out;
			$inst->{'fin'} = \@fin if @fin;
			$inst->{'fout'} = \@fout if @fout;
			$inst->{'wptr'} = $wptr;
			if ($data->{'wptr'}) {
				$wptr = sprintf ('wptr_%d', $wptr_n++);
				$inst->{'_wptr'} = $wptr;
			}
			if (0) {
				print "\t";
				print join (', ', @in, @fin), " => " if @in || @fin;
				print $name;
				if ($inst->{'label_arg'}) {
					print ' ', $inst->{'arg'}->{'name'};
				}
				print " => ", join (', ', @out, @fout) if @out || @fout;
				if ($data->{'wptr'}) {
					print " (", $inst->{'wptr'}, ' => ', $inst->{'_wptr'}, ")";
				}
				print "\n";
			}
			@stack = @stack[0..2] if @stack > 3;
			@fstack = @fstack[0..2] if @fstack > 3;
		}
		
		$label->{'out'} = [ @stack ];
		$label->{'fout'} = [ @fstack ];
		$label->{'_wptr'} = $wptr;
	}
}	

sub build_phi_nodes ($$) {
	my ($self, $labels) = @_;

	foreach my $label (@$labels) {
		my $lname = $label->{'name'};

		foreach my $inst (@{$label->{'inst'}}) {
			next if $inst->{'name'} ne 'CJ';
			my $tlabel = $inst->{'arg'};
			$tlabel->{'phi'} = {} if !$tlabel->{'phi'};
			$tlabel->{'phi'}->{$lname} = [ $label->{'wptr'}, @{$inst->{'in'}} ];
		}
	}
}


sub output_regs (@) {
	my (@regs) = @_;
	return if !@regs;
	my @out;
	foreach my $regs (@regs) {
		foreach my $reg (@$regs) {
			push (@out, '%' . $reg);
		}
	}
	return join (', ', @out);
}

sub proc_prefix {
	my $self = shift;
	return 'O_';
}

sub int_type {
	my $self = shift;
	return 'i32'; # FIXME:
}

sub int_length {
	my $self = shift;
	my $type = shift || $self->int_type;
	if ($type eq 'i16') {
		return 2;
	} elsif ($type eq 'i32') {
		return 4;
	} elsif ($type eq 'i64') {
		return 8;
	}
	die "Unknown integer type $type";
}

sub index_type {
	my $self = shift;
	if ($self->int_type eq 'i64') {
		return 'i64';
	} else {
		return 'i32';
	}
}

sub float_type {
	my $self = shift;
	return 'double';
}

sub sched_type {
	my $self = shift;
	return 'i8*';
}

sub func_type {
	my $self = shift;
	return sprintf ('void (%s, %s)', $self->sched_type, $self->workspace_type)
}

sub workspace_type {
	my $self = shift;
	return $self->int_type . '*';
}

sub reset_tmp ($) {
	my $self = shift;
	$self->{'tmp_n'} = 0;
}

sub tmp_label ($) {
	my $self = shift;
	my $n = $self->{'tmp_n'}++;
	return "tmp_$n";
}

sub tmp_reg ($) {
	my $self = shift;
	my $n = $self->{'tmp_n'}++;
	return "tmp_$n";
}

sub new_constant ($$$) {
	my ($self, $name, $value) = @_;
	die "Trying to create duplicate constant" if exists ($self->{'constants'}->{$name});
	$self->{'constants'}->{$name} = $value;
}

sub new_generated_constant ($$) {
	my ($self, $value) = @_;
	my $name = sprintf ('C_%d', $self->{'constant_n'}++);
	$self->new_constant ($name, $value);
	return $name;
}

sub source_file {
	my ($self, $file) = @_;
	if (defined ($file)) {
		$self->{'source_file'} = $self->{'source_files'}->{$file};
		if (!$self->{'source_file'}) {
			my $constant = $self->new_generated_constant (
				{ 'str' => $file }
			);
			$self->{'source_files'}->{$file} = $constant;
			$self->{'source_file'} = $constant;
		}
	}
	return $self->{'source_file'};
}

sub source_line {
	my ($self, $line) = @_;
	if (defined ($line)) {
		$self->{'source_line'} = $line;
	}
	return $self->{'source_line'};
}

sub int_constant ($$) {
	my ($self, $int) = @_;
	my $int_type = $self->int_type;
	return sprintf ('bitcast %s %d to %s', $int_type, $int, $int_type)
}

sub single_assignment ($$$$) {
	my ($self, $type, $src, $dst) = @_;
	return sprintf ('%%%s = bitcast %s %%%s to %s', $dst, $type, $src, $type);
}

sub global_ptr_value ($$$) {
	my ($self, $type, $global) = @_;
	my $tmp_reg = $self->tmp_reg ();
	return ($tmp_reg, 
		sprintf ('%%%s = load %s* @%s', $tmp_reg, $type, $global)
	);
}

sub _gen_error ($$$$$) {
	my ($self, $proc, $label, $inst, $type) = @_;
	my ($source_reg, $source_asm) = $self->global_ptr_value ('i8*', $self->source_file);
	my $symbol = 'etc_error_' . $type;
	$self->{'header'}->{$symbol} = [ 
		sprintf ('declare void @%s (%s, %s, i8*, %s)',
			$symbol, $self->sched_type, $self->workspace_type, $self->int_type
	)];
	return (
		$source_asm,
		sprintf ('call void @%s (%s %%sched, %s %%%s, i8* %%%s, %s %s)',
			$symbol,
			$self->sched_type,
			$self->workspace_type, $inst->{'wptr'},
			$source_reg,
			$self->int_type, $self->source_line
		)
	);
}

sub gen_j ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my @params = ( 
		sprintf ('%s %%sched', $self->sched_type),
		sprintf ('%s %%%s', $self->workspace_type, $inst->{'wptr'})
	);
	if ($inst->{'in'}) {
		for (my $i = 0; $i < @{$inst->{'in'}}; ++$i) {
			push (@params, sprintf ('%s %%%s', $self->int_type, $inst->{'in'}->[$i]));
		}
	}
	if ($inst->{'fin'}) {
		for (my $i = 0; $i < @{$inst->{'fin'}}; ++$i) {
			push (@params, sprintf ('%s %%%s', $self->float_type, $inst->{'fin'}->[$i]));
		}
	}
	return (
		sprintf ('tail call fastcc void %s (%s) noreturn',
			$proc->{'call_prefix'} . $inst->{'arg'}->{'name'},
			join (', ', @params)
		)
	);
}

sub gen_cj ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $next_label = $label->{'next'};
	my $tmp_reg = $self->tmp_reg ();
	my $jump_label = $self->tmp_label ();
	my $cont_label = $self->tmp_label ();
	return (
		sprintf ('%%%s = icmp eq %s %%%s, %d',
			$tmp_reg,
			$self->int_type, $inst->{'in'}->[0],
			0
		),
		sprintf ('br i1 %%%s, label %%%s, label %%%s',
			$tmp_reg,
			$jump_label, $cont_label
		),
		$jump_label . ':',
		sprintf ('tail call fastcc void %s (%s %%sched, %s %%%s) noreturn',
			$proc->{'call_prefix'} . $inst->{'arg'}->{'name'},
			$self->sched_type,
			$self->workspace_type,
			$inst->{'wptr'}
		),
		'ret void',
		$cont_label . ':',
		$self->gen_j ($proc, $label, {
			'in'	=> $next_label->{'in'},
			'fin'	=> $next_label->{'fin'},
			'wptr' 	=> $next_label->{'wptr'},
			'arg'	=> $next_label
		})
	);
}

sub gen_call ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $name 	= $inst->{'name'};
	my $wptr 	= $inst->{'wptr'};
	my $in		= $inst->{'in'};
	my $symbol 	= ref ($inst->{'arg'}) =~ /HASH/ ? $inst->{'arg'}->{'symbol'} : '';
	my $ffi		= ($symbol =~ m/^(C|BX?)\./)[0];
	my $reschedule	= $inst->{'reschedule'};
	my $tail_call	= 1;
	my (@asm, @params, $new_wptr);
	
	if (exists ($inst->{'fin'})) {
		my $msg = "WARNING: floating point stack is not empty at point of call";
		$self->message (1, $msg);
		push (@asm, "; $msg");
	}

	if ($name =~ /^G?CALL$/ || $reschedule) {
		my $iptr_offset = 0;

		$new_wptr = $self->tmp_reg ();

		if ($reschedule) {
			$iptr_offset = -1;
		} elsif ($name eq 'CALL') {
			$iptr_offset = -4;
		}

		push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
			$new_wptr,
			$self->workspace_type, $wptr,
			$self->index_type,
			$iptr_offset
		));

		if ($ffi ne 'C') {
			my $ret_ptr = $self->tmp_reg ();
			my $ret_val = $self->tmp_reg ();
			push (@asm, sprintf ('%%%s = bitcast %s %s to i8*',
				$ret_ptr,
				$self->func_type . '*' ,
				$proc->{'call_prefix'} . $label->{'next'}->{'name'}
			));
			push (@asm, sprintf ('%%%s = ptrtoint i8* %%%s to %s',
				$ret_val, 
				$ret_ptr,
				$self->int_type
			));
			push (@asm, sprintf ('store %s %%%s, %s %%%s',
				$self->int_type, $ret_val,
				$self->workspace_type, $new_wptr
			));
		}

		if ($name eq 'CALL') {
			for (my $i = 0; $i < @$in; ++$i) {
				my $tmp_reg = $self->tmp_reg ();
				push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
					$tmp_reg,
					$self->workspace_type, $new_wptr,
					$self->index_type, ($i + 1)
				));
				push (@asm, sprintf ('store %s %%%s, %s %%%s',
					$self->int_type, $in->[$i],
					$self->workspace_type, $tmp_reg
				));
			}
		} elsif (($name eq 'GCALL') && $in) {
			my $msg = "WARNING: stack is not empty at point of general call";
			$self->message (1, $msg);
			push (@asm, "; $msg");
		}
	}
	
	if ($ffi) {
		$symbol =~ s/^(C|BX?)//;
		$symbol =~ s/\./_/g;

		$self->{'header'}->{$symbol} = [
			sprintf ('declare void @%s (%s)', 
				$symbol, $self->workspace_type
			)
		] if !exists ($self->{'header'}->{$symbol});

		my $args_ptr = $self->tmp_reg ();
		push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
			$args_ptr,
			$self->workspace_type, $new_wptr,
			$self->index_type, 1
		));
		$in = [ $args_ptr ];
		
		if ($ffi =~ /B/) {
			my $args_val = $self->tmp_reg ();
			my $func_ptr = $self->tmp_reg ();
			my $func_val = $self->tmp_reg ();
			
			push (@asm, sprintf ('%%%s = ptrtoint %s %%%s to %s',
				$args_val,
				$self->workspace_type, $in->[0],
				$self->int_type
			));
			push (@asm, sprintf ('%%%s = bitcast void (%s)* @%s to i8*',
				$func_ptr, 
				$self->workspace_type, $symbol
			));
			push (@asm, sprintf ('%%%s = ptrtoint i8* %%%s to %s',
				$func_val,
				$func_ptr,
				$self->int_type
			));

			$in = [ $func_val, $args_val ];

			# Transform CALL into kernel call

			if ($ffi eq 'B') {
				$name = 'Y_b_dispatch';
			} elsif ($ffi eq 'BX') {
				$name = 'Y_bx_dispatch';
			}
			
			$name 		= $self->def_kcall ($name, { 'in' => $in });
			$ffi 		= undef;
			$reschedule	= 1;
		} else {
			$tail_call = 0;
		}
	}

	if ($name !~ /^G?CALL$/) {
		foreach my $param (@$in) {
			push (@params, sprintf ('%s %%%s',
				$self->int_type, $param
			));
		}
	}

	if ($name eq 'GCALL') {
		my $jump_ptr = $self->tmp_reg ();
		push (@asm, sprintf ('%%%s = inttoptr %s %%%s to void (%s, %s)',
			$jump_ptr,
			$self->int_type, $in->[0],
			$self->int_type, $self->workspace_type
		));
		push (@asm, sprintf ('tail call fastcc void %%%s (%s %%sched, %s %%%s) noreturn',
			$jump_ptr,
			$self->sched_type,
			$self->workspace_type,
			$wptr
		));
	} elsif ($name eq 'CALL') {
		if (!$ffi) {
			push (@asm, sprintf ('tail call fastcc void @%s%s (%s %%sched, %s %%%s) noreturn',
				$self->proc_prefix, $symbol,
				$self->sched_type,
				$self->workspace_type,
				$new_wptr
			));
		} else {
			push (@asm, sprintf ('call void @%s (%s %%%s)',
				$symbol,
				$self->workspace_type,
				$in->[0]
			));
		}	
	} else {
		my $ret = $inst->{'out'} && @{$inst->{'out'}} ? $inst->{'out'}->[0] : $self->tmp_reg ();

		push (@asm, sprintf ('%%%s = call %s @%s (%s %%sched, %s %%%s%s%s)',
			$ret,
			$reschedule ? $self->workspace_type : $self->int_type,
			$name,
			$self->sched_type,
			$self->workspace_type,
			$ffi ? $new_wptr : $wptr,
			@params ? ', ' : '',
			join (', ', @params)
		));
		
		if ($reschedule) {
			my $jump_ptr_ptr = $self->tmp_reg ();
			my $jump_ptr 	= $self->tmp_reg ();
			my $jump_val 	= $self->tmp_reg ();
			my $new_wptr	= $ret;
			push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
				$jump_ptr_ptr,
				$self->workspace_type, $new_wptr,
				$self->index_type, -1
			));
			push (@asm, sprintf ('%%%s = load %s %%%s',
				$jump_val, 
				$self->workspace_type, $jump_ptr_ptr
			));
			push (@asm, sprintf ('%%%s = inttoptr %s %%%s to void (%s, %s)*',
				$jump_ptr, 
				$self->int_type, $jump_val, 
				$self->sched_type, $self->workspace_type
			));
			push (@asm, sprintf ('tail call fastcc void %%%s (%s %%sched, %s %%%s) noreturn',
				$jump_ptr,
				$self->sched_type,
				$self->workspace_type, $new_wptr
			));
		} else {
			$tail_call = 0;
		}
	}

	if (!$tail_call) {
		my $next_label = $label->{'next'};
		push (@asm, $self->gen_j ($proc, $label, {
			'in'	=> $next_label->{'in'},
			'fin'	=> $next_label->{'fin'},
			'wptr' 	=> $next_label->{'wptr'},
			'arg'	=> $next_label
		}));
	}

	return @asm;
}	

sub gen_table ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $prefix	= $self->tmp_label () . '_';
	my $otherwise 	= $prefix . 'otherwise';
	my $targets 	= $inst->{'arg'};
	my (@asm, @jump_asm, @jump_labels);
	
	for (my $i = 0; $i < @$targets; ++$i) {
		my $target 	= $targets->[$i];
		my $lab 	= $prefix . $i;
		push (@jump_labels, $lab);
		push (@jump_asm, $lab . ':');
		push (@jump_asm, $self->gen_j ($proc, $label, 
			{ 'arg' => $target, 'wptr' => $inst->{'wptr'} }
		));
		push (@jump_asm, 'ret void');
	}

	push (@asm, sprintf ('switch %s %%%s, label %%%s [ %s %d, label %%%s',
		$self->int_type,
		$inst->{'in'}->[0],
		$otherwise,
		$self->int_type, 0, $jump_labels[0]
	));
	for (my $i = 1; $i < @jump_labels; ++$i) {
		push (@asm, sprintf ('  %s %d, label %%%s%s',
			$self->int_type, $i, $jump_labels[$i],
			$i == (@jump_labels - 1) ? ' ]' : ''
		));
	}
	push (@asm, @jump_asm);
	push (@asm, $otherwise . ':');
	push (@asm, 'unreachable');
	push (@asm, $self->gen_j ($proc, $label, 
		{ 'arg' => $label->{'next'}, 'wptr' => $inst->{'wptr'} }
	));

	return @asm;
}

sub gen_ajw ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return sprintf ('%%%s = getelementptr %s %%%s, %s %d',
		$inst->{'_wptr'},
		$self->workspace_type, $inst->{'wptr'},
		$self->index_type, $inst->{'arg'}
	);
}

sub gen_gajw ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return (
		sprintf ('%%%s = ptrtoint %s %%%s to %s',
			$self->{'out'}->[0], 
			$self->workspace_type, $inst->{'wptr'},
			$self->int_type
		),
		sprintf ('%%%s = inttoptr %s %%%s to %s',
			$inst->{'_wptr'}, 
			$self->int_type, $self->{'in'}->[0],
			$self->workspace_type
		)
	);
}

sub gen_ldc ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $arg = $inst->{'arg'};
	if (ref ($arg)) {
		my $name 	= $arg->{'name'};
		my (@load, $tmp_reg);

		if ($arg->{'data'}) {
			$self->new_constant ($name, $arg)
				if !exists ($self->{'constants'}->{$name});
			($tmp_reg, @load) = $self->global_ptr_value ('i8*', $name);
		} else {
			$tmp_reg = $self->tmp_reg ();
			@load = ( sprintf ('%%%s = bitcast %s %s to i8*',
				$tmp_reg, 
				$self->func_type . '*',
				$proc->{'call_prefix'} . $name
			));
		}

		return (
			@load,
			sprintf ('%%%s = ptrtoint i8* %%%s to %s',
				$inst->{'out'}->[0], 
				$tmp_reg,
				$self->int_type
			)
		);
	} else {
		return sprintf ('%%%s = %s',
			$inst->{'out'}->[0],
			$self->int_constant ($arg)
		);
	}
}

sub gen_ldinf ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->int_constant (0x7f800000);
}

sub gen_mint ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $type = $self->int_type;
	my $bits = ($type =~ /i(\d+)/)[0];
	my $mint = -(1 << ($bits - 1));
	return $self->gen_ldc ($proc, $label, {
		'out' => $inst->{'out'},
		'arg' => $mint
	});
}

sub gen_null ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->gen_ldc ($proc, $label, {
		'out' => $inst->{'out'},
		'arg' => 0
	});
}

sub _gen_ldlp ($$) {
	my ($self, $inst) = @_;
	my ($reg, @asm);
	if ($inst->{'arg'} != 0) {
		$reg = $self->tmp_reg ();
		push (@asm, 
			sprintf ('%%%s = getelementptr %s %%%s, %s %d',
				$reg, 
				$self->workspace_type, $inst->{'wptr'},
				$self->index_type, $inst->{'arg'}
		));
	} else {
		$reg = $inst->{'wptr'};
	}
	return ($reg, @asm);
}

sub gen_ldlp ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my ($tmp_reg, @asm) = $self->_gen_ldlp ($inst);
	my $conv = sprintf ('%%%s = ptrtoint %s %%%s to %s',
		$inst->{'out'}->[0],
		$self->workspace_type,
		$tmp_reg,
		$self->int_type
	);
	return (@asm, $conv);
}

sub gen_ldl ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my ($tmp_reg, @asm) = $self->_gen_ldlp ($inst);
	my $load = sprintf ('%%%s = load %s %%%s',
		$inst->{'out'}->[0],
		$self->workspace_type, $tmp_reg
	);
	return (@asm, $load);
}	

sub gen_stl ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my ($tmp_reg, @asm) = $self->_gen_ldlp ($inst);
	my $store = sprintf ('store %s %%%s, %s %%%s',
		$self->int_type, $inst->{'in'}->[0],
		$self->workspace_type, $tmp_reg
	);
	return (@asm, $store);
}

sub _gen_ldnlp ($$) {
	my ($self, $inst) = @_;
	my ($reg, @asm);
	my $ptr_reg = $self->tmp_reg ();
	push (@asm,
		sprintf ('%%%s = inttoptr %s %%%s to %s',
			$ptr_reg, 
			$self->int_type, $inst->{'in'}->[0], 
			$self->int_type . '*'
		)
	);
	if ($inst->{'arg'} != 0) {
		$reg = $self->tmp_reg ();
		push (@asm, 
			sprintf ('%%%s = getelementptr %s %%%s, %s %d',
				$reg, 
				$self->int_type . '*', $ptr_reg,
				$self->index_type, $inst->{'arg'}
		));
	} else {
		$reg = $ptr_reg;
	}
	return ($reg, @asm);
}

sub gen_ldnl ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my ($tmp_reg, @asm) = $self->_gen_ldnlp ($inst);
	my $load = sprintf ('%%%s = load %s %%%s',
		$inst->{'out'}->[0],
		$self->workspace_type, $tmp_reg
	);
	return (@asm, $load);
}	

sub gen_stnl ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my ($tmp_reg, @asm) = $self->_gen_ldnlp ($inst);
	my $store = sprintf ('store %s %%%s, %s %%%s',
		$self->int_type, $inst->{'in'}->[1],
		$self->workspace_type, $tmp_reg
	);
	return (@asm, $store);
}

sub gen_dup ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my @asm;
	my $in = $inst->{'in'}->[0];
	foreach my $reg (@{$inst->{'out'}}) {
		push (@asm, $self->single_assignment (
			$self->int_type, $inst->{'in'}->[0], $reg
		)); 
	}
	return @asm;
}

sub _gen_checked_arithmetic ($$$$$) {
	my ($self, $proc, $label, $inst, $func) = @_;
	my @asm;
	my $in		= $inst->{'in'};
	my $res 	= $self->tmp_reg ();
	my $overflow 	= $self->tmp_reg ();
	my $tmp		= $self->tmp_label ();
	my $error_lab	= $tmp . '_overflow_error';
	my $ok_lab	= $tmp . '_ok';

	push (@asm, sprintf ('%%%s = call {%s, i1} %s (%s %%%s, %s %%%s)',
		$res, 
		$self->int_type,
		$func,
		$self->int_type, $in->[0],
		$self->int_type, $in->[1]
	));
	push (@asm, sprintf ('%%%s = extractvalue {%s, i1} %%%s, 0',
		$inst->{'out'}->[0],
		$self->int_type,
		$res
	));
	push (@asm, sprintf ('%%%s = extractvalue {%s, i1} %%%s, 1',
		$overflow,
		$self->int_type,
		$res
	));
	push (@asm, sprintf ('br i1 %%%s, label %%%s, label %%%s',
		$overflow,
		$error_lab,
		$ok_lab
	));
	push (@asm, $error_lab . ':');
	push (@asm, $self->_gen_error ($proc, $label, $inst, 'overflow'));
	push (@asm, sprintf ('br label %%%s', $ok_lab));
	push (@asm, $ok_lab . ':');

	return @asm;
}

sub gen_add ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_checked_arithmetic (
		$proc, $label, $inst,
		'@llvm.sadd.with.overflow.' . $self->int_type
	);
}

sub gen_adc ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $tmp_reg = $self->tmp_reg ();
	my @ldc = $self->gen_ldc ($proc, $label, { 
		'arg' 	=> $inst->{'arg'},
		'out' 	=> [ $tmp_reg ]
	});
	my @add = $self->gen_add ($proc, $label, {
		'wptr'	=> $inst->{'wptr'},
		'in' 	=> [ @{$inst->{'in'}}, $tmp_reg ],
		'out'	=> $inst->{'out'}
	});
	return (@ldc, @add);
}

sub gen_sub ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_checked_arithmetic (
		$proc, $label, $inst,
		'@llvm.ssub.with.overflow.' . $self->int_type
	);
}

sub gen_mul ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_checked_arithmetic (
		$proc, $label, $inst,
		'@llvm.smul.with.overflow.' . $self->int_type
	);
}

sub gen_sum ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return sprintf ('%%%s = add %s %%%s, %%%s',
		$inst->{'out'}->[0],
		$self->int_type,
		$inst->{'in'}->[0], $inst->{'in'}->[1]
	);
}	

sub gen_diff ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return sprintf ('%%%s = sub %s %%%s, %%%s',
		$inst->{'out'}->[0],
		$self->int_type,
		$inst->{'in'}->[0], $inst->{'in'}->[1]
	);
}	

sub gen_prod ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return sprintf ('%%%s = mul %s %%%s, %%%s',
		$inst->{'out'}->[0],
		$self->int_type,
		$inst->{'in'}->[0], $inst->{'in'}->[1]
	);
}	

sub gen_divrem ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $mint 	= $self->tmp_reg ();
	my $cond_a_0	= $self->tmp_reg ();
	my $cond_a_m1	= $self->tmp_reg ();
	my $cond_b_mint	= $self->tmp_reg ();
	my $cond_error0	= $self->tmp_reg ();
	my $cond_error1	= $self->tmp_reg ();
	my $tmp		= $self->tmp_label ();
	my $error_lab	= $tmp . '_div_error';
	my $ok_lab	= $tmp . '_ok';
	my @asm;

	push (@asm, $self->gen_mint ($proc, $label, { 'out' => [ $mint ] }));
	push (@asm, sprintf ('%%%s = icmp eq %s %%%s, -1',
		$cond_a_m1, 
		$self->int_type, $inst->{'in'}->[0]
	));
	push (@asm, sprintf ('%%%s = icmp eq %s %%%s, %%%s',
		$cond_b_mint, 
		$self->int_type, $inst->{'in'}->[1],
		$mint
	));
	push (@asm, sprintf ('%%%s = and i1 %%%s, %%%s',
		$cond_error0, 
		$cond_a_m1, $cond_b_mint
	));
	push (@asm, sprintf ('%%%s = icmp eq %s %%%s, 0',
		$cond_a_0, 
		$self->int_type, $inst->{'in'}->[0]
	));
	push (@asm, sprintf ('%%%s = or i1 %%%s, %%%s',
		$cond_error1, 
		$cond_error0, $cond_a_0
	));
	push (@asm, sprintf ('br i1 %%%s, label %%%s, label %%%s',
		$cond_error1,
		$error_lab, $ok_lab
	));
	push (@asm, $error_lab . ':');
	push (@asm, $self->_gen_error ($proc, $label, $inst, 'div'));
	push (@asm, sprintf ('br label %%%s', $ok_lab));
	push (@asm, $ok_lab . ':');
	push (@asm, sprintf ('%%%s = %s %s %%%s, %%%s',
		$inst->{'out'}->[0],
		($inst->{'name'} eq 'REM' ? 'srem' : 'sdiv'),
		$self->int_type,
		$inst->{'in'}->[1], $inst->{'in'}->[0]
	));

	return @asm;
}

sub gen_rev ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return (
		$self->single_assignment ($self->int_type, $inst->{'in'}->[0], $inst->{'out'}->[1]),
		$self->single_assignment ($self->int_type, $inst->{'in'}->[1], $inst->{'out'}->[0])
	);
}

sub gen_eqc ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $tmp_reg = $self->tmp_reg ();
	return (
		sprintf ('%%%s = icmp eq %s %%%s, %d', 
			$tmp_reg, 
			$self->int_type,
			$inst->{'in'}->[0], $inst->{'arg'}
		),
		sprintf ('%%%s = zext i1 %%%s to %s', 
			$inst->{'out'}->[0], 
			$tmp_reg,
			$self->int_type
		)
	);
}

sub gen_gt ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $tmp_reg = $self->tmp_reg ();
	return (
		sprintf ('%%%s = icmp sgt %s %%%s, %%%s', 
			$tmp_reg,
			$self->int_type,
			$inst->{'in'}->[0], $inst->{'in'}->[1]
		),
		sprintf ('%%%s = zext i1 %%%s to %s', 
			$inst->{'out'}->[0], 
			$tmp_reg,
			$self->int_type
		)
	);
}

sub _gen_bitop ($$$@) { 
	my ($self, $inst, $op, @in) = @_;
	return sprintf ('%%%s = %s %s %%%s, %d',
		$inst->{'out'}->[0],
		$op,
		$self->int_type, 
		@in
	);
}

sub gen_not ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'xor', @{$inst->{'in'}}, -1);
}

sub gen_xor ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'xor', @{$inst->{'in'}});
}

sub gen_or ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'xor', @{$inst->{'in'}});
}

sub gen_and ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'and', @{$inst->{'in'}});
}

sub gen_shr ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'lshr', @{$inst->{'in'}});
}

sub gen_shl ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'shl', @{$inst->{'in'}});
}

sub gen_boolinvert ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_bitop ($inst, 'xor', @{$inst->{'in'}}, 1);
}

sub gen_nop ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return ();
}

sub gen_ret ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $jump_val = $self->tmp_reg ();
	my $jump_ptr = $self->tmp_reg ();
	my $new_wptr = $self->tmp_reg ();
	my @asm;
	push (@asm, sprintf ('%%%s = load %s %%%s',
		$jump_val, 
		$self->workspace_type, $inst->{'wptr'}
	));
	push (@asm, sprintf ('%%%s = inttoptr %s %%%s to void (%s, %s)*',
		$jump_ptr, 
		$self->int_type, $jump_val, 
		$self->sched_type, $self->workspace_type
	));
	push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
		$new_wptr,
		$self->workspace_type, $inst->{'wptr'},
		$self->index_type, 4
	));
	push (@asm, sprintf ('tail call fastcc void %%%s (%s %%sched, %s %%%s) noreturn',
		$jump_ptr,
		$self->sched_type,
		$self->workspace_type, $new_wptr
	));
	return @asm;
}

sub gen_csub0 ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $error 	= $self->tmp_reg ();
	my $tmp		= $self->tmp_label ();
	my $error_lab	= $tmp . '_bounds_error';
	my $ok_lab	= $tmp . '_ok';
	my @asm;
	push (@asm, $self->single_assignment (
		$self->int_type, $inst->{'in'}->[1], $inst->{'out'}->[0]
	));
	push (@asm, sprintf ('%%%s = icmp uge %s %%%s, %%%s',
		$error, $self->int_type, $inst->{'in'}->[1], $inst->{'in'}->[0]
	));
	push (@asm, sprintf ('br i1 %%%s, label %%%s, label %%%s',
		$error, $error_lab, $ok_lab
	));
	push (@asm, $error_lab . ':');
	push (@asm, $self->_gen_error ($proc, $label, $inst, 'bounds'));
	push (@asm, sprintf ('br label %%%s', $ok_lab));
	push (@asm, $ok_lab . ':');

	return @asm;
}

sub gen_bsub ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	return $self->gen_sum ($proc, $label, $inst);
}

sub gen_wsub ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $tmp_reg = $self->tmp_reg ();
	return (
		sprintf ('%%%s = mul %s %%%s, %d',
			$tmp_reg,
			$self->int_type, $inst->{'in'}->[1],
			$self->int_length * ($inst->{'name'} eq 'WSUBDB' ? 2 : 1)
		),
		$self->gen_sum ($proc, $label, {
			'wptr' 	=> $inst->{'wptr'},
			'in'	=> [ $inst->{'in'}->[0], $tmp_reg ],
			'out'	=> $inst->{'out'}
		})
	);
}

sub gen_lb ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $byte_ptr = $self->tmp_reg ();
	my $byte_val = $self->tmp_reg ();
	return (
		sprintf ('%%%s = inttoptr %s %%%s to i8*',
			$byte_ptr, 
			$self->int_type, $inst->{'in'}->[0], 
		),
		sprintf ('%%%s = load i8* %%%s',
			$byte_val, $byte_ptr
		),
		sprintf ('%%%s = zext i8 %%%s to %s',
			$inst->{'out'}->[0],
			$byte_val, $self->int_type
		)
	);
}

sub gen_sb ($$$$) { 
	my ($self, $proc, $label, $inst) = @_;
	my $byte_ptr = $self->tmp_reg ();
	my $byte_val = $self->tmp_reg ();
	return (
		sprintf ('%%%s = inttoptr %s %%%s to i8*',
			$byte_ptr, 
			$self->int_type, $inst->{'in'}->[0], 
		),
		sprintf ('%%%s = trunc %s %%%s to i8',
			$byte_val, 
			$self->int_type, $inst->{'in'}->[1]
		),
		sprintf ('store i8 %%%s, i8* %%%s',
			$byte_val, $byte_ptr
		)
	);
}

sub gen_seterr ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	return $self->_gen_error ($proc, $label, $inst, 'set');
}

sub gen_lend ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $block_ptr		= $self->tmp_reg ();
	my $index_ptr		= $self->tmp_reg ();
	my $block_cnt		= $self->tmp_reg ();
	my $new_block_cnt	= $self->tmp_reg ();
	my $index_cnt		= $self->tmp_reg ();
	my $new_index_cnt	= $self->tmp_reg ();
	my $loop_cond		= $self->tmp_reg ();
	my $loop_lab		= $self->tmp_label ();
	my $next_lab		= $self->tmp_label ();
	my @asm;
	
	# Generate pointer to index block
	push (@asm, sprintf ('%%%s = inttoptr %s %%%s to %s',
		$index_ptr, $self->int_type, $inst->{'in'}->[0], $self->int_type . '*'
	));
	# Decrement index
	push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
		$block_ptr,
		$self->int_type . '*', $index_ptr,
		$self->index_type, 1
	));
	push (@asm, sprintf ('%%%s = load %s %%%s',
		$block_cnt,
		$self->int_type . '*', $block_ptr
	));
	push (@asm, sprintf ('%%%s = sub %s %%%s, %d',
		$new_block_cnt,
		$self->int_type, $block_cnt, 1
	));
	push (@asm, sprintf ('store %s %%%s, %s %%%s',
		$self->int_type, $new_block_cnt,
		$self->int_type . '*', $block_ptr
	));

	# Compare index to zero
	push (@asm, sprintf ('%%%s = icmp ugt %s %%%s, %d',
		$loop_cond,
		$self->int_type, $new_block_cnt, 0
	));
	push (@asm, sprintf ('br i1 %%%s, label %%%s, label %%%s',
		$loop_cond, $loop_lab, $next_lab
	));

	# index > 0, Keep looping
	push (@asm, $loop_lab . ':');
	
	# Update count
	push (@asm, sprintf ('%%%s = load %s %%%s',
		$index_cnt,
		$self->int_type . '*', $index_ptr
	));

	if ($inst->{'name'} eq 'LEND') {
		push (@asm, sprintf ('%%%s = add %s %%%s, %d',
			$new_index_cnt,
			$self->int_type, $index_cnt, 1
		));
	} elsif ($inst->{'name'} eq 'LENDB') {
		push (@asm, sprintf ('%%%s = sub %s %%%s, %d',
			$new_index_cnt,
			$self->int_type, $index_cnt, 1
		));
	} else {
		my $step_ptr = $self->tmp_reg ();
		my $step_val = $self->tmp_reg ();
		push (@asm, sprintf ('%%%s = getelementptr %s %%%s, %s %d',
			$step_ptr,
			$self->int_type . '*', $index_ptr,
			$self->index_type, 2
		));
		push (@asm, sprintf ('%%%s = load %s %%%s',
			$step_val,
			$self->int_type . '*', $step_ptr
		));
		push (@asm, sprintf ('%%%s = add %s %%%s, %%%s',
			$new_index_cnt,
			$self->int_type, $index_cnt, $step_val
		));
	}

	push (@asm, sprintf ('store %s %%%s, %s %%%s',
		$self->int_type, $new_index_cnt,
		$self->int_type . '*', $index_ptr
	));

	# Loop
	push (@asm, $self->gen_j ($proc, $label, 
		{ 'wptr' => $inst->{'wptr'}, 'arg' => $inst->{'arg'} }
	));
	push (@asm, 'ret void');
	
	# index = 0, Exit loop
	push (@asm, $next_lab . ':');
	push (@asm, $self->gen_j ($proc, $label, 
		{ 'wptr' => $inst->{'wptr'}, 'arg' => $label->{'next'} }
	));

	return @asm;
}

sub def_kcall ($$$) {
	my ($self, $symbol, $inst) = @_;
	my $name 	= 'kernel_' . $symbol;
	my $reschedule	= $symbol =~ /^Y_/ ? 1 : 0;

	if (!exists ($self->{'header'}->{$name})) {
		my @param = ($self->sched_type, $self->workspace_type);
		
		if ($inst->{'in'}) {
			for (my $i = 0; $i < @{$inst->{'in'}}; ++$i) {
				push (@param, $self->int_type);
			}
		}
		
		$self->{'header'}->{$name} = [ sprintf (
			'declare %s @%s (%s)',
			$reschedule ? $self->workspace_type : $self->int_type, 
			$name, join (', ', @param)
		) ];
	}

	return $name;
}

sub _gen_kcall ($$$$$) {
	my ($self, $proc, $label, $inst, $symbol) = @_;
	my $reschedule 	= $symbol =~ /^Y_/ ? 1 : 0;
	
	die "Unknown kernel call " . $inst->{'name'} . " ($symbol)" if $symbol !~ /^[XY]_/;

	my $name = $self->def_kcall ($symbol, $inst);

	return $self->gen_call ($proc, $label, {
		'name' 		=> $name,
		'in'		=> $inst->{'in'},
		'out'		=> $inst->{'out'},
		'wptr'		=> $inst->{'wptr'},
		'reschedule' 	=> $reschedule
	});
}

sub gen_kcall ($$$$) {
	my ($self, $proc, $label, $inst) = @_;
	my $data = $GRAPH->{$inst->{'name'}};
	return $self->_gen_kcall ($proc, $label, $inst, $data->{'symbol'});
}

sub format_lines (@) {
	my @lines = @_;
	my @asm;
	foreach my $line (@lines) {
		if ($line =~ /^(\@|[a-zA-Z0-9\$\._]+:|de(clare|fine))/ || $line =~ /[{}]\s*$/) {
			push (@asm, $line);
		} else {
			push (@asm, "\t" . $line);
		}
		push (@asm, '') if $line =~ /^([@}]|declare)/;
	}
	return @asm;
}

sub generate_proc ($$) {
	my ($self, $proc) = @_;
	my $symbol 	= '@' . $self->proc_prefix . $proc->{'symbol'};
	my $call_pfix 	= $symbol . '_';
	my @asm;

	$proc->{'call_prefix'} = $call_pfix;

	
	push (@asm, format_lines (
		sprintf ('define fastcc void %s (%s %%sched, %s %%wptr) {', 
			$symbol,
			$self->sched_type, $self->workspace_type
		),
		'entry:',
		sprintf ('tail call fastcc void %s (%s %%sched, %s %%wptr) noreturn',
			$call_pfix . $proc->{'labels'}->[0]->{'name'},
			$self->sched_type, $self->workspace_type
		),
		'ret void',
		'}'
	));

	# Alias for C linking
	if ($symbol =~ /\./) {
		my $alias = $symbol;
		$alias =~ s/\./_/g;
		push (@asm, sprintf ('%s = alias %s %s',
			$alias, $self->func_type . '*', $symbol
		));
	}

	foreach my $label (@{$proc->{'labels'}}) {
		my ($name, $insts) = ($label->{'name'}, $label->{'inst'});
		my $last_inst;

		if (1) {
			my $sym_name = sprintf ('%s_%s', $symbol, $name);
			my @types = ( $self->sched_type, $self->workspace_type );
			my @params = (
				sprintf ('%s %%sched', $self->sched_type),
				sprintf ('%s %%%s', $self->workspace_type, $label->{'wptr'})
			);
			for (my $i = 0; $i < @{$label->{'in'}}; ++$i) {
				push (@types, $self->int_type);
				push (@params, sprintf ('%s %%%s', $self->int_type, $label->{'in'}->[$i]));
			}
			for (my $i = 0; $i < @{$label->{'fin'}}; ++$i) {
				push (@types, $self->float_type);
				push (@params, sprintf ('%s %%%s', $self->float_type, $label->{'fin'}->[$i]));
			}
			
			$self->{'header'}->{$sym_name} = [
				sprintf ('declare fastcc void %s (%s)',
					$sym_name,
					join (', ', @types)
				)
			];
			
			push (@asm,
				sprintf ('define private fastcc void %s (%s) {',
					$sym_name,
					join (', ', @params)
			));
			push (@asm, $name . ':');

		} elsif ($label->{'phi'}) {
			my $wptr	= $label->{'wptr'};
			my $in 		= $label->{'in'} || [];
			my $fin 	= $label->{'fin'} || [];
			my @vars 	= ( $wptr, @$in, @$fin );
			my %var_map 	= ( map { $_ => [] } @vars ); # build hash of arrays for each var
			my %type 	= ( $wptr => $self->workspace_type );
			foreach my $var (@$in) {
				$type{$var} = $self->int_type;
			}
			foreach my $var (@$fin) {
				$type{$var} = $self->float_type;
			}
			my $wptr_same = 1;
			foreach my $slabel (keys (%{$label->{'phi'}})) {
				my $svars = $label->{'phi'}->{$slabel};
				for (my $i = 0; $i < @vars; ++$i) {
					$wptr_same = $wptr_same && $vars[$i] eq $svars->[$i]
						if $i == 0;
					push (@{$var_map{$vars[$i]}},
						'[ %' . $svars->[$i] . ', %' . $slabel . ' ]'
					);
				}
			}
			shift @vars if $wptr_same;
			foreach my $var (@vars) {
				push (@asm, join ('', 
					"\t", '%', $var, 
					' = phi ', $type{$var}, ' ', join (' ', @{$var_map{$var}})
				));
			}
		}
		
		for (my $inst_idx = 0; $inst_idx < @$insts; ++$inst_idx) {
			my $inst	= $insts->[$inst_idx];
			my $name 	= $inst->{'name'};
			
			if ($name =~ /^\./) {
				if ($name eq '.LINE') {
					$self->source_line ($inst->{'arg'});
				} elsif ($name eq '.FILENAME') {
					$self->source_file ($inst->{'arg'});
				}
				next;
			}
			
			my $line = "\t; $name";
			if (exists ($inst->{'arg'})) {
				$line .= " ";
				if (exists ($inst->{'label_arg'})) {
					if (ref ($inst->{'arg'}) =~ /ARRAY/) {
						if ($name eq 'LDC' && @{$inst->{'arg'}} == 2) {
							$inst->{'arg'} = $inst->{'arg'}->[0];
							$line .= $inst->{'arg'}->{'name'};
						} elsif ($name eq 'TABLE') {
							my @names = map { $_->{'name'} } @{$inst->{'arg'}};
							$line .= join (', ', @names);
						} else {
							my @names = map { $_->{'name'} } @{$inst->{'arg'}};
							print STDERR "Unknown label array for $name ",
								join (', ', @names), "\n";
							exit 0;
						}
					} else {
						$line .= $inst->{'arg'}->{'name'};
					}
				} else {
					$line .= $inst->{'arg'};
				}
			}
			push (@asm, $line);
			
			my $data	= $GRAPH->{$name};
			my $in 		= $inst->{'in'} || [];
			my $fin 	= $inst->{'fin'} || [];
			my $out 	= $inst->{'out'} || [];
			my $fout 	= $inst->{'fout'} || [];
			
			if ($data->{'generator'}) {
				my @lines = &{$data->{'generator'}}($self, $proc, $label, $inst);
				push (@asm, format_lines (@lines));
			} elsif ($data->{'kcall'}) {
				my @lines = $self->gen_kcall ($proc, $label, $inst);
				push (@asm, format_lines (@lines));
			} elsif (@$out + @$fout == 1) {
				my $line = "\t";
				$line .= output_regs ($out, $fout);
				$line .= " = call void \@op_" . $name . " (%" . $inst->{'wptr'};
				$line .= ', ' . $inst->{'arg'} if exists ($inst->{'arg'});
				$line .= ', ' if (@$in + @$fin > 0);
				$line .= output_regs ($in, $fin);
				$line .= ')';
				push (@asm, $line);
			} else {
				my $line = "\t";
				$line .= '%', $inst->{'_wptr'}, ' = ' if $inst->{'_wptr'};
				$line .= "call void \@op_" . $name . " (%" . $inst->{'wptr'};
				$line .= ', ' . $inst->{'arg'} if exists ($inst->{'arg'});
				$line .= ', ' if (@$in + @$fin > 0);
				$line .= output_regs ($in, $fin, $out, $fout);
				$line .= ")";
				push (@asm, $line);
			}
			
			$last_inst = $inst;
		}

		my $last_data = $GRAPH->{$last_inst->{'name'}};
		if ($last_inst->{'name'} ne 'RET' && !($last_data->{'branching'} || $last_data->{'kcall'})) {
			my $next_label = $label->{'next'};
			push (@asm, format_lines (
				$self->gen_j ($proc, $label, {
					'in'	=> $next_label->{'in'},
					'fin'	=> $next_label->{'fin'},
					'wptr' 	=> $next_label->{'wptr'},
					'arg'	=> $next_label
				})
			));
		}
		push (@asm, format_lines ('ret void', '}'));
	}
	#push (@asm, '}') if !$prev_call;

	return @asm;
}

sub code_constants ($) {
	my $self = shift;
	my $constants = $self->{'constants'};
	my @asm;

	foreach my $name (sort (keys (%$constants))) {
		my $value = $constants->{$name};
		my $align = undef;
		my @data;
		if (exists ($value->{'str'})) {
			my $str = $value->{'str'};
			@data = split (//, $str);
			foreach my $chr (@data) {
				$chr = ord ($chr);
			}
			push (@data, 0);
			push (@asm, "; \@$name = \"$str\"");
		} elsif (exists ($value->{'data'})) {
			$align = $value->{'align'};
			@data = unpack ('C*', $value->{'data'}); 
		}
		
		foreach my $val (@data) {
			$val = sprintf ('i8 %d', $val);
		}

		push (@asm, sprintf ('@%s_value = internal constant [ %d x i8 ] [ %s ]%s',
			$name, scalar (@data), join (', ', @data),
			($align ? ', align ' . (2 ** $align) : '')
		));
		push (@asm, sprintf ('@%s = internal constant i8* getelementptr ([ %d x i8 ]* @%s_value, i32 0, i32 0)',
			$name, scalar (@data), $name
		));
	}

	return @asm;
}

sub code_proc ($$) {
	my ($self, $proc) = @_;
	
	$self->reset_tmp ();

	$self->define_registers ($proc->{'labels'});
	$self->build_phi_nodes ($proc->{'labels'});
	
	my $comments = "; " . $proc->{'symbol'};
	return ($comments, $self->generate_proc ($proc));
}

sub intrinsics ($) {
	my $self = shift;
	my $int = $self->int_type;
	return (
		"declare { $int, i1 } \@llvm.sadd.with.overflow.$int ($int, $int)",
		"declare { $int, i1 } \@llvm.smul.with.overflow.$int ($int, $int)",
		"declare { $int, i1 } \@llvm.ssub.with.overflow.$int ($int, $int)"
	);
}

sub generate ($@) {
	my ($self, @texts) = @_;
	my $verbose = $self->{'verbose'};
	my @proc_asm;
	
	foreach my $text (@texts) {
		my $file	= $text->{'file'};
		my $etc		= $text->{'etc'};

		$self->preprocess_etc ($file, $etc);

		foreach my $proc (@{$self->{'procs'}}) {
			push (@proc_asm, $self->code_proc ($proc));
		}
	}
	
	my @header 	= $self->intrinsics;
	my @const_asm 	= $self->code_constants ();
	foreach my $elem (sort (keys (%{$self->{'header'}}))) {
		push (@header, @{$self->{'header'}->{$elem}});
	}

	return (@header, @const_asm, @proc_asm);
}

sub build_tlp_desc {
	my ($self, $symbol)	= @_;
	my $def			= $symbol->{'definition'};
	my ($params)		= ($def =~ m/PROC\s+\S+\(([^\)]+)\)/s);
	my @params		= split (/,/, $params);
	my @tlp;

	foreach my $param (@params) {
		my $shared = 0;
		
		if ($param =~ /^FIXED SHARED/) {
			$param =~ s/^FIXED SHARED\s*//;
			$shared = 1;
		}
		
		if ($param =~ m/^CHAN\s+OF\s+(\S+)\s+(\S+)/) {
			my ($type, $name)	= ($1, $2);
			my ($dir)		= ($name =~ m/([\?!])$/);
			if (!$dir) {
				($dir) = ($def =~ m/$name([\?!])/gs);
				$dir = '.' if !$dir;
			}
			$name = 'keyboard?' 	if $name =~ /(kyb|key(board)?)/ && $dir =~ /[.?]/;
			$name = 'screen!' 	if $name =~ /(scr(een)?)/ && $dir =~ /[.!]/;
			$name = 'error!' 	if $name =~ /(err(or)?)/ && $dir =~ /[.!]/;
			push (@tlp, $name);
		} else {
			push (@tlp, 'unknown');
		}
	}

	push (@tlp, 'VSPTR') 	if $symbol->{'vs'};
	push (@tlp, 'MSPTR')	if $symbol->{'ms'};
	push (@tlp, 'FBARPTR') 	if $def =~ /PROC.*\(.*\).*FORK/;

	return @tlp;
}

sub entry_point ($$) {
	my ($self, $symbol) = @_;
	my $name	= $symbol->{'string'};
	my $ws		= $symbol->{'ws'};
	my $vs		= $symbol->{'vs'};
	my $ms		= $symbol->{'ms'};
	my @tlp_desc	= $self->build_tlp_desc ($symbol); 
	my @asm;

	my @tlp_elem;
	for (my $i = 0; $i < @tlp_desc; ++$i) {
		my $elem = $tlp_desc[$i];
		push (@asm, sprintf ('@tlp_%d = internal constant [ %d x i8 ] c"%s\00"',
			$i, length ($tlp_desc[$i]) + 1, $tlp_desc[$i]
		));
		push (@tlp_elem, sprintf ('i8* getelementptr ([ %d x i8 ]* @tlp_%d, i32 0, i32 0)',
			length ($tlp_desc[$i]) + 1, $i
		));
	}

	push (@asm, sprintf ('@tlp_desc = internal constant [ %d x i8* ] [ %s, i8* null ]',
		@tlp_elem + 1, join (', ', @tlp_elem) 
	));
	push (@asm,
		sprintf ('declare %s @occam_start (%s, i8**, i8*, i8**, i8*, %s, %s, %s)',
			$self->int_type, 
			$self->int_type, 
			$self->int_type, $self->int_type, $self->int_type
		)
	);

	push (@asm,
		sprintf ('define private fastcc void @code_exit (%s %%sched, %s %%wptr) {',
			$self->sched_type,
			$self->workspace_type
		),
		# FIXME: handle fork barrier
		'ret void',
		'}'
	);
	
	push (@asm,
		sprintf ('define void @code_entry (%s %%sched, %s %%wptr) {',
			$self->sched_type, $self->workspace_type
		),
		sprintf ('%%iptr_ptr = getelementptr %s %%wptr, %s %d',
			$self->workspace_type,
			$self->index_type, -1
		),
		sprintf ('%%iptr_val = load %s %%iptr_ptr',
			$self->workspace_type
		),
		sprintf ('%%iptr = inttoptr %s %%iptr_val to %s',
			$self->int_type,
			$self->func_type . '*'
		),
		sprintf ('%%ret_ptr = bitcast %s @code_exit to i8*',
			$self->func_type . '*',
		),
		sprintf ('%%ret_val = ptrtoint i8* %%ret_ptr to %s',
			$self->int_type
		),
		sprintf ('store %s %%ret_val, %s %%wptr',
			$self->int_type,
			$self->workspace_type
		),
		sprintf ('tail call fastcc void %%iptr (%s %%sched, %s %%wptr) noreturn',
			$self->sched_type,
			$self->workspace_type
		),
		'ret void',
		'}',
	);

	push (@asm, 
		sprintf ('define %s @main (%s %%argc, i8** %%argv) {',
			$self->int_type, $self->int_type
		),
		'entry:',
		"; ENTRY POINT: $name, WS = $ws, VS = $vs, MS = $ms",
		sprintf ('%%code_entry = bitcast %s @code_entry to i8*',
			$self->func_type . '*'
		),
		sprintf ('%%start_proc = bitcast %s @%s%s to i8*',
			$self->func_type . '*',
			$self->proc_prefix,
			$name
		),
		sprintf ('%%ret = call %s @occam_start (%s %%argc, i8** %%argv'
			 	. ', i8* %%code_entry, i8** getelementptr ([ %d x i8* ]* @tlp_desc, i32 0, i32 0)'
				. ', i8* %%start_proc, %s %d, %s %d, %s %d)',
			$self->int_type,
			$self->int_type,
			@tlp_elem + 1,
			$self->int_type, $ws,
			$self->int_type, $vs,
			$self->int_type, $ms
		),
		sprintf ('ret %s %%ret',
			$self->int_type
		),
		'}'
	);

	return format_lines (@asm); 
}

1;