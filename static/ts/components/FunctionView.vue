<template>
    <div @click="select">
        

        <select v-model="func.expr">
            <option v-for="stdfun in func.availableFunctions()">{{ stdfun }}</option>
        </select>
        <p>{{ func.getDescription() }}</p>

        <Cell-List v-bind:cells="func.args" v-bind:readonly="true"/>

        <Result-View v-bind:cell="func"/>
        
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import * as util from '../utils';
import * as constants from '../constants';

export default Vue.component('FunctionView', {
    name: 'FunctionView',
    props: ['func'],

    methods: {
        select: function(event: Event) {
            event.stopPropagation();
        }
    }

});
</script>

<style>
</style>
