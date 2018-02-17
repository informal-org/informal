<template>
    <li v-bind:class="classObject" @mousedown="select" >
        <template v-if="isEdit">
            <button type="button" class="close" aria-label="Close" v-on:click="destruct">
                <span aria-hidden="true">&times;</span>
            </button>

            <input maxlength="20" class="DataLabel" v-model="group.name" placeholder="Name..."/>
        </template>
        <template v-else>
            <label class="DataLabel">{{ group.name }}&nbsp;</label>
        </template>


        <ul class="list-group">
            <template v-for="cell in group.expr">
                <template v-if="cell.type == 'group'">
                    <Cell-List :key="cell.id" v-bind:group="cell"></Cell-List>
                </template>
                <template v-else>
                    <Cell :key="cell.id" v-bind:cell="cell"></Cell>
                </template>
            </template>
            <!--<template v-if="onadd !== undefined">-->
                <!--<a class="list-group-item list-group-item-action AddItem" @mousedown="addNewCell">-->
                    <!--<i class="fas fa-plus"></i>-->
                    <!--Add Item-->
                    <!--</a>-->
            <!--</template>-->
        </ul>




        <div class="alert alert-danger CellError" role="alert" v-for="error in group.errors">
              <i class="fas fa-exclamation-triangle"></i> &nbsp; {{error}}
        </div>

    </li>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('CellList', {
    name: 'CellList',
    props: {
        'group': {type: Group},
    },
    computed: {
        classObject: function() : object {
            let classes: {[index: string]: any} =  {
                "list-group-item": true,
                "DataGroup": true
            };
            return classes;
        },
        isEdit: function() : boolean {
            return false;
        },
    },
    methods: {
        select: function(event: Event) {
            // @ts-ignore:
            if(this.isEdit) {
                // Hide this mousedown event from selector so our input boxes can be edited.
                event.stopPropagation();
            }
        },
        addCell: function(event: Event) {
            // todo: Vuex this
            // let c = new Cell("", "test", this.cellgroup.env, "hello");
            // let c = this.cellgroup.env.createCell("", "", "")
            // this.cellgroup.addChild(c);
            // window.lastAddedIndex = this.cellgroup.env.all_cells.indexOf(c);
        },
    },
    watch: {
      isEdit: function (val) {
         if(val) {
             let el = this.$el;
             // Wait till after element is added.
             setTimeout(function() {
                let input = el.querySelector('input');
                if(input != undefined && input != null){
                    input.focus();
                }
             }, 100);
         }
       }
    }
});
</script>

<style>
</style>
