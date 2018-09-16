<template>
    <div>
        <Cell-View v-if="cell._result_type === 'OBJ'" v-bind:readonly="true" v-bind:cell="cell.evaluate()"/>
        <Cell-List v-else-if="cell._result_type === 'ARR'" v-bind:readonly="true" v-bind:cells="cell.evaluate()"/>
        <span v-else>{{ cell.toString() }}</span>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import * as util from '../utils';
import * as constants from '../constants';

export default Vue.component('ResultView', {
    name: 'ResultView',
    props: ['cell'],
});
</script>

<style>
</style>
